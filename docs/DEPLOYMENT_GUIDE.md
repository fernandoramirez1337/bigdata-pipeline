# Guía de Despliegue - Pipeline Big Data NYC Taxi

## Índice
1. [Prerrequisitos](#prerrequisitos)
2. [Configuración de EC2](#configuración-de-ec2)
3. [Instalación paso a paso](#instalación-paso-a-paso)
4. [Verificación](#verificación)
5. [Despliegue de Jobs](#despliegue-de-jobs)
6. [Configuración de Dashboards](#configuración-de-dashboards)
7. [Troubleshooting](#troubleshooting)

---

## Prerrequisitos

### Cuentas AWS Academy
- 3-4 cuentas AWS Academy con $50 cada una
- Acceso a AWS Learner Lab
- Región: us-east-1 (Virginia)

### Instancias EC2 Requeridas

| Instancia | Tipo | vCPU | RAM | Storage | IP Privada |
|-----------|------|------|-----|---------|------------|
| EC2-1 Master | t3.large | 2 | 8 GB | 100 GB | 10.0.x.x |
| EC2-2 Worker1 | t3.xlarge | 4 | 16 GB | 200 GB | 10.0.x.x |
| EC2-3 Worker2 | t3.xlarge | 4 | 16 GB | 200 GB | 10.0.x.x |
| EC2-4 Storage | t3.large | 2 | 8 GB | 150 GB | 10.0.x.x |

### Dataset
- NYC Yellow Taxi Trip Data
- Fuente: https://www.kaggle.com/datasets/elemento/nyc-yellow-taxi-trip-data
- 12 meses de datos (2015-01 a 2015-12)
- ~40-60 GB total

---

## Configuración de EC2

### Paso 1: Lanzar Instancias

1. Ir a AWS Console → EC2 → Launch Instance
2. Seleccionar AMI: **Amazon Linux 2023**
3. Configurar Security Group:

```
Inbound Rules:
- SSH (22) - Your IP
- Custom TCP (8080-8088) - VPC CIDR (10.0.0.0/16)
- Custom TCP (9000-9092) - VPC CIDR
- Custom TCP (6123) - VPC CIDR
- Custom TCP (7077) - VPC CIDR
- PostgreSQL (5432) - VPC CIDR
```

4. Storage: Configurar según tabla arriba
5. Key Pair: Crear o seleccionar existente
6. Launch

### Paso 2: Configurar IPs Estáticas (Elastic IPs)

Para facilitar la configuración, asignar Elastic IPs:

```bash
# En AWS Console:
# EC2 → Elastic IPs → Allocate Elastic IP address
# Asociar cada EIP a su instancia correspondiente
```

### Paso 3: Configurar /etc/hosts en todas las instancias

SSH a cada instancia y ejecutar:

```bash
sudo tee -a /etc/hosts <<EOF
<MASTER_PRIVATE_IP> master-node ec2-master
<WORKER1_PRIVATE_IP> worker1-node ec2-worker1
<WORKER2_PRIVATE_IP> worker2-node ec2-worker2
<STORAGE_PRIVATE_IP> storage-node ec2-storage
EOF
```

---

## Instalación paso a paso

### Opción A: Instalación Automatizada (Recomendado)

#### 1. Clonar el repositorio en tu máquina local

```bash
git clone https://github.com/fernandoramirez1337/bigdata-pipeline.git
cd bigdata-pipeline
```

#### 2. Actualizar IPs en scripts

Editar `infrastructure/scripts/orchestrate-cluster.sh`:

```bash
MASTER_IP="<MASTER_PRIVATE_IP>"
WORKER1_IP="<WORKER1_PRIVATE_IP>"
WORKER2_IP="<WORKER2_PRIVATE_IP>"
STORAGE_IP="<STORAGE_PRIVATE_IP>"
SSH_KEY="~/.ssh/your-key.pem"
```

#### 3. Ejecutar setup automatizado

```bash
chmod +x infrastructure/scripts/*.sh
./infrastructure/scripts/orchestrate-cluster.sh setup-all
```

Este proceso tomará ~30-45 minutos.

#### 4. Iniciar el cluster

```bash
./infrastructure/scripts/orchestrate-cluster.sh start-cluster
```

#### 5. Verificar estado

```bash
./infrastructure/scripts/orchestrate-cluster.sh status
```

### Opción B: Instalación Manual

#### En Master Node (EC2-1):

```bash
# SSH a master
ssh -i your-key.pem ec2-user@<MASTER_PUBLIC_IP>

# Copiar script de setup
scp -i your-key.pem infrastructure/scripts/common-setup.sh ec2-user@<MASTER_IP>:~
scp -i your-key.pem infrastructure/scripts/setup-master.sh ec2-user@<MASTER_IP>:~

# Ejecutar setup
bash common-setup.sh
bash setup-master.sh

# Formatear HDFS (solo primera vez)
hdfs namenode -format

# Iniciar servicios
sudo systemctl start zookeeper
sudo systemctl start kafka
$HADOOP_HOME/sbin/start-dfs.sh
$SPARK_HOME/sbin/start-master.sh
$FLINK_HOME/bin/jobmanager.sh start
```

#### En Worker Nodes (EC2-2, EC2-3):

```bash
# SSH a worker1
ssh -i your-key.pem ec2-user@<WORKER1_PUBLIC_IP>

# Copiar scripts
scp -i your-key.pem infrastructure/scripts/common-setup.sh ec2-user@<WORKER1_IP>:~
scp -i your-key.pem infrastructure/scripts/setup-worker.sh ec2-user@<WORKER1_IP>:~

# Ejecutar setup (pasar worker ID: 1 o 2)
bash common-setup.sh
bash setup-worker.sh 1

# Iniciar servicios
sudo systemctl start hadoop-datanode
sudo systemctl start spark-worker
sudo systemctl start flink-taskmanager
```

Repetir para Worker2 con ID 2.

#### En Storage Node (EC2-4):

```bash
# SSH a storage
ssh -i your-key.pem ec2-user@<STORAGE_PUBLIC_IP>

# Copiar scripts
scp -i your-key.pem infrastructure/scripts/common-setup.sh ec2-user@<STORAGE_IP>:~
scp -i your-key.pem infrastructure/scripts/setup-storage.sh ec2-user@<STORAGE_IP>:~

# Ejecutar setup
bash common-setup.sh
bash setup-storage.sh

# Configurar AWS CLI
aws configure
# AWS Access Key ID: <YOUR_KEY>
# AWS Secret Access Key: <YOUR_SECRET>
# Default region: us-east-1

# Crear S3 bucket
aws s3 mb s3://bigdata-taxi-results-<YOUR_UNIQUE_ID>

# Iniciar servicios
sudo systemctl start hadoop-datanode
sudo systemctl start postgresql
sudo systemctl start superset
```

---

## Verificación

### 1. Verificar Web UIs

Abrir en navegador:

- **HDFS NameNode**: http://<MASTER_PUBLIC_IP>:9870
  - Verificar: 3 DataNodes activos

- **Spark Master**: http://<MASTER_PUBLIC_IP>:8080
  - Verificar: 2 Workers activos

- **Flink Dashboard**: http://<MASTER_PUBLIC_IP>:8081
  - Verificar: 2 TaskManagers activos

- **Superset**: http://<STORAGE_PUBLIC_IP>:8088
  - Login: admin / admin

### 2. Verificar Kafka

```bash
# SSH a master
ssh -i your-key.pem ec2-user@<MASTER_IP>

# Listar topics
$KAFKA_HOME/bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# Crear topic si no existe
$KAFKA_HOME/bin/kafka-topics.sh --create \
    --bootstrap-server localhost:9092 \
    --replication-factor 1 \
    --partitions 3 \
    --topic taxi-trips-stream
```

### 3. Verificar HDFS

```bash
# SSH a master
hdfs dfs -ls /

# Crear directorios
hdfs dfs -mkdir -p /data/taxi/raw
hdfs dfs -mkdir -p /spark-logs
hdfs dfs -mkdir -p /flink-checkpoints
hdfs dfs -chmod -R 777 /
```

### 4. Verificar PostgreSQL

```bash
# SSH a storage
psql -U bigdata -d bigdata_taxi -c "\dt"

# Debería mostrar las tablas:
# - real_time_zones
# - real_time_global
# - top_active_zones
# - daily_summary
# - hourly_zone_stats
# - route_analysis
```

---

## Despliegue de Jobs

### 1. Descargar y Preparar Dataset

**Opción A: Descargar a local y subir a S3**

```bash
# En tu máquina local
# Descargar dataset de Kaggle (requiere cuenta)
kaggle datasets download -d elemento/nyc-yellow-taxi-trip-data

# Subir a S3
aws s3 cp yellow_tripdata_2015-01.parquet s3://bigdata-taxi-dataset/nyc-taxi/
# Repetir para todos los meses
```

**Opción B: Descargar directamente a EC2**

```bash
# SSH a master o storage con más espacio
cd /tmp
wget <DATASET_URL>
aws s3 cp yellow_tripdata_2015-*.parquet s3://bigdata-taxi-dataset/nyc-taxi/
```

### 2. Configurar y Desplegar Data Producer

```bash
# SSH a master
cd /home/ec2-user
git clone https://github.com/fernandoramirez1337/bigdata-pipeline.git
cd bigdata-pipeline/data-producer

# Instalar dependencias
pip3 install -r requirements.txt

# Actualizar config.yaml
vim config.yaml
# Cambiar:
# - kafka.bootstrap_servers → ["<MASTER_IP>:9092"]
# - dataset.s3.bucket → "bigdata-taxi-dataset"

# Ejecutar producer
nohup python3 src/producer.py --config config.yaml > producer.log 2>&1 &

# Ver logs
tail -f producer.log
```

### 3. Compilar y Desplegar Jobs de Flink

```bash
# SSH a master
cd /home/ec2-user/bigdata-pipeline/streaming

# Compilar
bash build.sh

# Actualizar IPs en ZoneAggregationJob.java antes de compilar:
# - KAFKA_BROKERS → "<MASTER_IP>:9092"
# - JDBC_URL → "jdbc:postgresql://<STORAGE_IP>:5432/bigdata_taxi"

# Desplegar job
$FLINK_HOME/bin/flink run \
    flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar

# Verificar en UI
# http://<MASTER_PUBLIC_IP>:8081
```

### 4. Desplegar Jobs de Spark Batch

```bash
# SSH a master
cd /home/user/bigdata-pipeline/batch/spark-jobs

# Actualizar IPs en daily_summary.py:
# - HDFS_INPUT → "hdfs://<MASTER_IP>:9000/data/taxi/raw"
# - POSTGRES_URL → "jdbc:postgresql://<STORAGE_IP>:5432/bigdata_taxi"

# Ejecutar job manualmente
$SPARK_HOME/bin/spark-submit \
    --master spark://<MASTER_IP>:7077 \
    --driver-memory 2g \
    --executor-memory 4g \
    --executor-cores 2 \
    daily_summary.py

# Configurar cron para ejecución diaria
crontab -e
# Agregar:
0 2 * * * $SPARK_HOME/bin/spark-submit --master spark://<MASTER_IP>:7077 /home/ec2-user/bigdata-pipeline/batch/spark-jobs/daily_summary.py >> /var/log/bigdata/spark-daily.log 2>&1
```

---

## Configuración de Dashboards

### 1. Conectar Superset a PostgreSQL

```bash
# Acceder a Superset
http://<STORAGE_PUBLIC_IP>:8088

# Login: admin / admin

# 1. Ir a: Data → Databases → + Database
# 2. Seleccionar: PostgreSQL
# 3. Configurar:
#    - Host: localhost
#    - Port: 5432
#    - Database: bigdata_taxi
#    - User: bigdata
#    - Password: bigdata123
# 4. Test Connection
# 5. Save
```

### 2. Crear Datasets

```
1. Ir a: Data → Datasets → + Dataset
2. Seleccionar database: bigdata_taxi
3. Agregar tablas:
   - real_time_zones
   - real_time_global
   - daily_summary
   - hourly_zone_stats
   - route_analysis
```

### 3. Crear Dashboards

#### Dashboard de Tiempo Real

```
1. Ir a: Dashboards → + Dashboard
2. Nombre: "NYC Taxi - Real Time"
3. Agregar charts:

Chart 1: Big Number - Active Trips
- Dataset: real_time_zones
- Metric: SUM(trip_count)
- Filter: window_start > NOW() - 1 minute

Chart 2: Line Chart - Trips/Minute
- Dataset: real_time_zones
- X-axis: window_start
- Metric: SUM(trip_count)
- Time range: Last 30 minutes
- Auto refresh: 10 seconds

Chart 3: Bar Chart - Top Zones
- Dataset: real_time_zones
- X-axis: zone_id
- Metric: SUM(trip_count)
- Time range: Last 5 minutes
- Limit: 10

Chart 4: Pie Chart - Payment Methods
- Dataset: real_time_zones
- Dimensions: payment type (calculated)
- Metric: SUM(count)
```

#### Dashboard Histórico

```
1. Ir a: Dashboards → + Dashboard
2. Nombre: "NYC Taxi - Historical Analysis"
3. Agregar charts:

Chart 1: Line Chart - Daily Trend
- Dataset: daily_summary
- X-axis: date
- Metrics: total_trips, total_revenue
- Time range: Last 30 days

Chart 2: Heatmap - Hourly Demand
- Dataset: hourly_zone_stats
- X-axis: hour
- Y-axis: day_of_week
- Metric: SUM(trip_count)

Chart 3: Table - Top Routes
- Dataset: route_analysis
- Columns: pickup_zone, dropoff_zone, route_count, avg_fare
- Sort: route_count DESC
- Limit: 20
```

---

## Troubleshooting

### Problema: Kafka no puede conectar

```bash
# Verificar que Kafka esté corriendo
sudo systemctl status kafka

# Verificar Zookeeper
sudo systemctl status zookeeper

# Ver logs
tail -f /opt/bigdata/kafka/logs/server.log

# Reiniciar
sudo systemctl restart zookeeper
sudo systemctl restart kafka
```

### Problema: HDFS DataNode no conecta

```bash
# Verificar logs
tail -f /var/log/bigdata/hadoop/hadoop-ec2-user-datanode-*.log

# Verificar conectividad
telnet <MASTER_IP> 9000

# Reiniciar DataNode
sudo systemctl restart hadoop-datanode

# En master, verificar:
hdfs dfsadmin -report
```

### Problema: Flink job falla

```bash
# Ver logs del job
$FLINK_HOME/bin/flink list
$FLINK_HOME/bin/flink log <JOB_ID>

# Verificar conectividad a Kafka y PostgreSQL
telnet <MASTER_IP> 9092
telnet <STORAGE_IP> 5432

# Cancelar y reiniciar job
$FLINK_HOME/bin/flink cancel <JOB_ID>
$FLINK_HOME/bin/flink run target/taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

### Problema: No hay datos en Superset

```bash
# Verificar que producer esté corriendo
ps aux | grep producer

# Verificar que Flink job esté activo
# http://<MASTER_IP>:8081

# Verificar datos en PostgreSQL
psql -U bigdata -d bigdata_taxi
SELECT COUNT(*) FROM real_time_zones;
SELECT * FROM real_time_zones ORDER BY window_start DESC LIMIT 10;

# Si no hay datos, verificar Kafka
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic taxi-trips-stream \
    --from-beginning \
    --max-messages 10
```

---

## Estimación de Costos y Tiempos

### Costos por Hora (4 EC2)
- t3.large (2x): $0.1664/hora
- t3.xlarge (2x): $0.3328/hora
- Total: ~$0.50/hora

### Con $50 disponibles
- Tiempo de operación: ~100 horas
- Estrategia: Apagar cuando no se use

### Tiempo de Setup
- Instalación automatizada: 30-45 minutos
- Descarga de dataset: 1-2 horas
- Configuración de dashboards: 30 minutos
- Total: 2-3 horas

---

## Próximos Pasos

1. Monitorear el pipeline por 24 horas
2. Ajustar parámetros si es necesario
3. Crear snapshots de EBS para backup
4. Optimizar queries de Superset
5. Implementar alertas (opcional)

---

## Soporte

Para problemas o preguntas:
- GitHub Issues: https://github.com/fernandoramirez1337/bigdata-pipeline/issues
- Email: [tu_email]
