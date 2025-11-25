#!/bin/bash

# Load cluster IPs
for config in ".cluster-ips" "../.cluster-ips" "../../.cluster-ips"; do
    [ -f "$config" ] && source "$config" && break
done

# Defaults
MASTER_IP="${MASTER_IP:-18.204.220.35}"
WORKER1_IP="${WORKER1_IP:-98.93.42.124}"
WORKER2_IP="${WORKER2_IP:-3.83.20.48}"
STORAGE_IP="${STORAGE_IP:-34.229.16.230}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/bigd-key.pem}"
SSH_USER="${SSH_USER:-ec2-user}"

usage() {
    cat << EOF
Usage: $0 <command>

Commands:
  setup-all       Setup all nodes
  start-cluster   Start all services
  stop-cluster    Stop all services
  status          Check status
  create-topics   Create Kafka topics
  deploy-jobs     Deploy jobs
  start-producer  Start producer
  start-flink-job Start Flink job
  start-spark-job Start Spark job
  init-db         Initialize database
  start-superset  Start Superset
EOF
    exit 1
}

check_config() {
    [[ ! -f "$SSH_KEY" ]] && echo "ERROR: SSH key not found: $SSH_KEY" && exit 1
}

ssh_exec() {
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$1 "$2" 2>/dev/null || true
}

setup_all() {
    check_config
    echo "Setting up cluster..."

    for node in "$MASTER_IP" "$WORKER1_IP" "$WORKER2_IP" "$STORAGE_IP"; do
        scp -i $SSH_KEY -o StrictHostKeyChecking=no infrastructure/scripts/common-setup.sh $SSH_USER@$node:/home/ec2-user/ &>/dev/null
    done

    scp -i $SSH_KEY infrastructure/scripts/setup-{master,worker,worker,storage}.sh $SSH_USER@$MASTER_IP:/home/ec2-user/ &>/dev/null

    ssh_exec $MASTER_IP "bash /home/ec2-user/setup-master.sh"
    ssh_exec $WORKER1_IP "bash /home/ec2-user/setup-worker.sh 1" &
    ssh_exec $WORKER2_IP "bash /home/ec2-user/setup-worker.sh 2" &
    wait
    ssh_exec $STORAGE_IP "bash /home/ec2-user/setup-storage.sh"
    
    echo "Setup complete."
}

start_cluster() {
    check_config
    echo "Starting cluster..."

    ssh_exec $MASTER_IP "source /etc/profile.d/bigdata.sh && \$ZOOKEEPER_HOME/bin/zkServer.sh start"
    sleep 5

    ssh_exec $MASTER_IP "source /etc/profile.d/bigdata.sh && nohup \$KAFKA_HOME/bin/kafka-server-start.sh \$KAFKA_HOME/config/server.properties > /var/log/bigdata/kafka.log 2>&1 &"
    sleep 10

    ssh_exec $MASTER_IP "source /etc/profile.d/bigdata.sh && [ ! -d /data/hdfs/namenode/current ] && hdfs namenode -format -force; \$HADOOP_HOME/bin/hdfs --daemon start namenode"
    sleep 10

    ssh_exec $STORAGE_IP "sudo systemctl start postgresql; source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon start datanode"
    ssh_exec $WORKER1_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon start datanode" &
    ssh_exec $WORKER2_IP "source /etc/profile.d/bigdata.sh && \$HADOOP_HOME/bin/hdfs --daemon start datanode" &
    wait
    sleep 5

    ssh_exec $MASTER_IP "source /etc/profile.d/bigdata.sh && hdfs dfs -mkdir -p /data/taxi/raw /spark-logs /flink-checkpoints /flink-savepoints && hdfs dfs -chmod -R 777 /"

    ssh_exec $MASTER_IP "source /etc/profile.d/bigdata.sh && \$SPARK_HOME/sbin/start-master.sh"
    sleep 5
    ssh_exec $WORKER1_IP "source /etc/profile.d/bigdata.sh && \$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077" &
    ssh_exec $WORKER2_IP "source /etc/profile.d/bigdata.sh && \$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077" &
    wait

    ssh_exec $MASTER_IP "source /etc/profile.d/bigdata.sh && \$FLINK_HOME/bin/jobmanager.sh start"
    sleep 5
    ssh_exec $WORKER1_IP "source /etc/profile.d/bigdata.sh && \$FLINK_HOME/bin/taskmanager.sh start" &
    ssh_exec $WORKER2_IP "source /etc/profile.d/bigdata.sh && \$FLINK_HOME/bin/taskmanager.sh start" &
    wait

    echo "Cluster started."
    check_status
}

stop_cluster() {
    check_config
    echo "Stopping cluster..."

    ssh_exec $MASTER_IP "\$FLINK_HOME/bin/jobmanager.sh stop"
    ssh_exec $WORKER1_IP "sudo systemctl stop flink-taskmanager" &
    ssh_exec $WORKER2_IP "sudo systemctl stop flink-taskmanager" &
    wait

    ssh_exec $WORKER1_IP "sudo systemctl stop spark-worker" &
    ssh_exec $WORKER2_IP "sudo systemctl stop spark-worker" &
    wait
    ssh_exec $MASTER_IP "\$SPARK_HOME/sbin/stop-master.sh"

    ssh_exec $MASTER_IP "\$HADOOP_HOME/sbin/stop-dfs.sh"
    ssh_exec $MASTER_IP "sudo systemctl stop kafka zookeeper"

    echo "Cluster stopped."
}

check_status() {
    check_config
    echo "Cluster Status:"
    echo ""

    echo "Master ($MASTER_IP):"
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$MASTER_IP "
        jps | grep -q NameNode && echo '  HDFS NameNode: running' || echo '  HDFS NameNode: stopped'
        jps | grep -q Master && echo '  Spark Master: running' || echo '  Spark Master: stopped'
        jps | grep -q StandaloneSessionClusterEntrypoint && echo '  Flink JobManager: running' || echo '  Flink JobManager: stopped'
    " 2>/dev/null

    for worker in "Worker1:$WORKER1_IP" "Worker2:$WORKER2_IP"; do
        name="${worker%:*}"
        ip="${worker#*:}"
        echo "$name ($ip):"
        ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$ip "
            jps | grep -q DataNode && echo '  HDFS DataNode: running' || echo '  HDFS DataNode: stopped'
            jps | grep -q Worker && echo '  Spark Worker: running' || echo '  Spark Worker: stopped'
            jps | grep -q TaskManagerRunner && echo '  Flink TaskManager: running' || echo '  Flink TaskManager: stopped'
        " 2>/dev/null
    done

    echo "Storage ($STORAGE_IP):"
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$STORAGE_IP "
        jps | grep -q DataNode && echo '  HDFS DataNode: running' || echo '  HDFS DataNode: stopped'
        sudo systemctl is-active postgresql &>/dev/null && echo '  PostgreSQL: running' || echo '  PostgreSQL: stopped'
    " 2>/dev/null

    echo ""
    echo "Web UIs:"
    echo "  HDFS:     http://$MASTER_IP:9870"
    echo "  Spark:    http://$MASTER_IP:8080"
    echo "  Flink:    http://$MASTER_IP:8081"
    echo "  Superset: http://$STORAGE_IP:8088"
}

create_kafka_topics() {
    check_config
    echo "Creating Kafka topics..."
    ssh_exec $MASTER_IP "\$KAFKA_HOME/bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --replication-factor 1 --partitions 3 --topic taxi-trips-stream --config compression.type=snappy --config retention.ms=86400000 2>/dev/null || echo 'Topic exists'; \$KAFKA_HOME/bin/kafka-topics.sh --list --bootstrap-server localhost:9092"
}

[ $# -eq 0 ] && usage

case "$1" in
    setup-all)
        setup_all
        ;;
    start-cluster)
        start_cluster
        ;;
    stop-cluster)
        stop_cluster
        ;;
    status)
        check_status
        ;;
    create-topics)
        create_kafka_topics
        ;;
    deploy-jobs)
        check_config
        echo "Deploying jobs..."
        cd ../../data-producer
        ssh_exec $MASTER_IP "mkdir -p ~/bigdata-pipeline/data-producer"
        scp -i $SSH_KEY -r src config.yaml requirements.txt synthetic_producer.py $SSH_USER@$MASTER_IP:~/bigdata-pipeline/data-producer/ &>/dev/null
        cd ../streaming && bash build.sh &>/dev/null
        scp -i $SSH_KEY flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar $SSH_USER@$MASTER_IP:~/ &>/dev/null
        cd ../batch/spark-jobs
        ssh_exec $MASTER_IP "mkdir -p ~/bigdata-pipeline/batch/spark-jobs"
        scp -i $SSH_KEY *.py $SSH_USER@$MASTER_IP:~/bigdata-pipeline/batch/spark-jobs/ &>/dev/null
        echo "Jobs deployed."
        ;;
    start-producer)
        check_config
        echo "Starting producer..."
        ssh_exec $MASTER_IP "cd ~/bigdata-pipeline/data-producer && pip3 install kafka-python &>/dev/null && nohup python3 synthetic_producer.py > /var/log/bigdata/synthetic_producer.log 2>&1 &"
        echo "Producer started."
        ;;
    start-flink-job)
        check_config
        echo "Starting Flink job..."
        ssh_exec $MASTER_IP "/opt/bigdata/flink/bin/flink run -d ~/taxi-streaming-jobs-1.0-SNAPSHOT.jar"
        echo "Flink job submitted."
        ;;
    start-spark-job)
        check_config
        echo "Starting Spark job..."
        ssh_exec $MASTER_IP "/opt/bigdata/spark/bin/spark-submit --master spark://master-node:7077 --deploy-mode client --driver-memory 512m --executor-memory 1g --executor-cores 1 --packages org.postgresql:postgresql:42.6.0 ~/bigdata-pipeline/batch/spark-jobs/daily_summary.py"
        echo "Spark job submitted."
        ;;
    init-db)
        check_config
        echo "Initializing database..."
        scp -i $SSH_KEY ../../database/schema.sql $SSH_USER@$STORAGE_IP:~/ &>/dev/null
        ssh_exec $STORAGE_IP "sudo -u postgres psql -c 'CREATE DATABASE bigdata_taxi;' 2>/dev/null || true; sudo -u postgres psql -c \"CREATE USER bigdata WITH PASSWORD 'bigdata123';\" 2>/dev/null || true; sudo -u postgres psql -c 'GRANT ALL PRIVILEGES ON DATABASE bigdata_taxi TO bigdata;' 2>/dev/null || true; PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -f ~/schema.sql 2>&1 | grep -v 'already exists' | grep -v 'NOTICE' || true"
        echo "Database initialized."
        ;;
    start-superset)
        check_config
        echo "Starting Superset..."
        ssh -i $SSH_KEY -o StrictHostKeyChecking=no $SSH_USER@$STORAGE_IP "cd /opt/bigdata/superset && source venv/bin/activate && export FLASK_APP=superset && export SUPERSET_CONFIG_PATH=/opt/bigdata/superset/superset_config.py && nohup superset run -h 0.0.0.0 -p 8088 --with-threads > /var/log/bigdata/superset.log 2>&1 &"
        echo "Superset started."
        ;;
    *)
        echo "Unknown command: $1"
        usage
        ;;
esac
