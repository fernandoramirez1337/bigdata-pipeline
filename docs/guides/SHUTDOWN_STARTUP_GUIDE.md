# Guía de Apagado y Arranque del Cluster

## 🔴 Apagar el Cluster

### Comando Rápido
```bash
./infrastructure/scripts/shutdown-cluster.sh
```

### Qué hace el script

1. **Para Flink** (TaskManagers → JobManager)
2. **Para Spark** (Workers → Master)
3. **Para HDFS** (DataNodes → NameNode)
4. **Para Kafka**
5. **Para Zookeeper**
6. **Para PostgreSQL** (opcional, pregunta)

### Orden de apagado (importante)
```
Applications/Jobs
    ↓
Flink Cluster
    ↓
Spark Cluster
    ↓
HDFS Cluster
    ↓
Kafka
    ↓
Zookeeper
    ↓
PostgreSQL (opcional)
```

### Tiempo estimado
**~2 minutos** para apagar todos los servicios

### Después del shutdown

Los servicios Java estarán detenidos, pero **las instancias EC2 seguirán corriendo**.

#### Opción 1: Dejar instancias corriendo (pagas EC2 completo)
```bash
# No hacer nada adicional
# Instancias siguen online, puedes hacer SSH
```

#### Opción 2: Detener instancias EC2 (pagas solo storage)
```bash
# AWS Console
EC2 Dashboard → Instances → Select all 4 → Actions → Stop

# O AWS CLI (reemplaza con tus instance IDs)
aws ec2 stop-instances --instance-ids \
  i-xxxmaster \
  i-xxxworker1 \
  i-xxxworker2 \
  i-xxxstorage
```

**Ventaja**: Pagas solo EBS storage (~$0.10/GB/mes)
**Desventaja**: IP pública cambia al reiniciar

#### Opción 3: Terminar instancias (elimina todo)
```bash
# AWS Console
EC2 Dashboard → Instances → Select all 4 → Actions → Terminate

# O AWS CLI
aws ec2 terminate-instances --instance-ids \
  i-xxxmaster \
  i-xxxworker1 \
  i-xxxworker2 \
  i-xxxstorage
```

**Ventaja**: No pagas nada
**Desventaja**: Pierdes todo (configuración, datos, etc.)

---

## 🟢 Arrancar el Cluster

### Pre-requisito: Instancias EC2 corriendo

Si detuviste las instancias EC2, primero iníci alas:

```bash
# AWS Console
EC2 Dashboard → Instances → Select all 4 → Actions → Start

# O AWS CLI
aws ec2 start-instances --instance-ids \
  i-xxxmaster \
  i-xxxworker1 \
  i-xxxworker2 \
  i-xxxstorage
```

**Importante**: Si las IPs públicas cambiaron, actualiza:
- `infrastructure/scripts/*.sh` (variables MASTER_IP, WORKER1_IP, etc.)
- O exporta las variables antes de ejecutar:
  ```bash
  export MASTER_IP=nueva-ip-master
  export WORKER1_IP=nueva-ip-worker1
  # etc.
  ```

### Comando Rápido
```bash
./infrastructure/scripts/start-cluster.sh
```

### Qué hace el script

1. **Inicia Zookeeper** (coordinación)
2. **Inicia Kafka** (message broker)
3. **Inicia HDFS** (NameNode → DataNodes)
4. **Inicia Spark** (Master → Workers)
5. **Inicia Flink** (JobManager → TaskManagers)
6. **Verifica PostgreSQL** (debería estar auto-iniciado)

### Orden de inicio (importante)
```
Zookeeper
    ↓
Kafka (depende de Zookeeper)
    ↓
HDFS Cluster (NameNode → DataNodes)
    ↓
Spark Cluster (Master → Workers)
    ↓
Flink Cluster (JobManager → TaskManagers)
    ↓
PostgreSQL (auto-start con systemd)
```

### Tiempo estimado
**~3 minutos** para iniciar todos los servicios y estabilizarse

### Verificación post-inicio

```bash
# Dashboard visual
./infrastructure/scripts/cluster-dashboard.sh

# Verificación completa
./infrastructure/scripts/verify-cluster-health.sh
```

**Esperado**: `CLUSTER HEALTH: EXCELLENT`

---

## 📋 Comparación de Opciones

### Tabla de Decisión

| Escenario | Acción | Costo | Tiempo Reinicio | Datos Persisten |
|-----------|--------|-------|-----------------|-----------------|
| **Pausa corta** (horas) | Solo `shutdown-cluster.sh` | 💰💰💰 Alto (EC2 full) | ⚡ 3 min | ✅ Sí |
| **Pausa media** (días) | Shutdown + Stop EC2 | 💰 Bajo (storage) | 🕐 5-10 min | ✅ Sí |
| **Proyecto terminado** | Shutdown + Terminate EC2 | 💸 Gratis | ⛔ N/A (reconstruir) | ❌ No |
| **Solo reiniciar servicios** | `shutdown` + `start` | 💰💰💰 Alto | ⚡ 5 min | ✅ Sí |

### Recomendaciones

**Si vas a volver en pocas horas**:
```bash
./infrastructure/scripts/shutdown-cluster.sh
# Dejar instancias EC2 corriendo
```

**Si vas a volver en días/semanas**:
```bash
./infrastructure/scripts/shutdown-cluster.sh
# Luego detener instancias EC2 desde AWS Console
```

**Si terminaste el proyecto**:
```bash
./infrastructure/scripts/shutdown-cluster.sh
# Luego terminar instancias EC2 desde AWS Console
# Opcional: Hacer snapshot de volúmenes EBS antes
```

---

## 🔧 Reinicio de Servicios Individuales

Si solo necesitas reiniciar un servicio específico:

### HDFS
```bash
# NameNode
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop namenode
$HADOOP_HOME/bin/hdfs --daemon start namenode

# DataNode (en cualquier worker)
ssh -i ~/.ssh/bigd-key.pem ec2-user@<worker-ip>
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
$HADOOP_HOME/bin/hdfs --daemon start datanode
```

### Kafka
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
source /etc/profile.d/bigdata.sh
$KAFKA_HOME/bin/kafka-server-stop.sh
sleep 5
nohup $KAFKA_HOME/bin/kafka-server-start.sh $KAFKA_HOME/config/server.properties > /var/log/bigdata/kafka.log 2>&1 &
```

### Spark
```bash
# Master
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
source /etc/profile.d/bigdata.sh
$SPARK_HOME/sbin/stop-master.sh
$SPARK_HOME/sbin/start-master.sh

# Worker
ssh -i ~/.ssh/bigd-key.pem ec2-user@<worker-ip>
source /etc/profile.d/bigdata.sh
$SPARK_HOME/sbin/stop-worker.sh
$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077
```

### Flink
```bash
# JobManager
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
source /etc/profile.d/bigdata.sh
$FLINK_HOME/bin/jobmanager.sh stop
$FLINK_HOME/bin/jobmanager.sh start

# TaskManager
ssh -i ~/.ssh/bigd-key.pem ec2-user@<worker-ip>
source /etc/profile.d/bigdata.sh
$FLINK_HOME/bin/taskmanager.sh stop
$FLINK_HOME/bin/taskmanager.sh start
```

### PostgreSQL
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.88.249.180
sudo systemctl restart postgresql
```

---

## ⚠️ Troubleshooting

### Problema: Script de shutdown se queda colgado

**Causa**: Algún servicio no responde al comando de stop
**Solución**: Force kill
```bash
# En el nodo específico
ssh -i ~/.ssh/bigd-key.pem ec2-user@<node-ip>
jps
# Encuentra el PID del proceso problemático
kill -9 <PID>
```

### Problema: Script de startup falla

**Causa**: Servicios anteriores no terminaron correctamente
**Solución**: Limpiar procesos y reintentar
```bash
# Ejecutar shutdown primero
./infrastructure/scripts/shutdown-cluster.sh

# Verificar que no haya procesos Java
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254 "jps"

# Si hay procesos, force kill
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254 "pkill java"

# Reintentar startup
./infrastructure/scripts/start-cluster.sh
```

### Problema: DataNodes no se conectan después de reinicio

**Causa**: NameNode binding o timing issue
**Solución**:
```bash
# Verificar que NameNode está escuchando en 0.0.0.0:9000
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
sudo netstat -tulnp | grep 9000

# Si muestra 127.0.0.1:9000, ejecutar fix
./infrastructure/scripts/fix-namenode-binding.sh

# Si muestra 0.0.0.0:9000, simplemente reiniciar DataNodes
./infrastructure/scripts/verify-cluster-health.sh
```

---

## 📊 Checklist de Apagado Seguro

Antes de apagar el cluster en producción:

- [ ] No hay jobs de Spark corriendo
- [ ] No hay jobs de Flink corriendo
- [ ] No hay consumers de Kafka activos
- [ ] Datos importantes están respaldados
- [ ] Documentaste el estado actual (para debugging futuro)
- [ ] Sabes cómo reiniciar (IPs, configuraciones, etc.)

---

## 💾 Backup Antes de Apagar (Recomendado)

Si tienes datos importantes:

```bash
# Backup de HDFS a S3
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
source /etc/profile.d/bigdata.sh
hadoop distcp hdfs:///data s3a://your-bucket/hdfs-backup/

# Backup de PostgreSQL
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.88.249.180
pg_dump -U bigdata taxi_analytics > backup_$(date +%Y%m%d).sql

# Copiar backup a tu máquina local
scp -i ~/.ssh/bigd-key.pem ec2-user@98.88.249.180:~/backup_*.sql .
```

---

## 🎯 Resumen de Comandos

### Apagar
```bash
./infrastructure/scripts/shutdown-cluster.sh
```

### Arrancar
```bash
./infrastructure/scripts/start-cluster.sh
```

### Verificar
```bash
./infrastructure/scripts/cluster-dashboard.sh
./infrastructure/scripts/verify-cluster-health.sh
```

### Detener EC2 (AWS CLI)
```bash
aws ec2 stop-instances --instance-ids i-xxx i-yyy i-zzz i-www
```

### Iniciar EC2 (AWS CLI)
```bash
aws ec2 start-instances --instance-ids i-xxx i-yyy i-zzz i-www
```

---

**Última actualización**: 20 de Noviembre 2025
**Mantenedor**: DevOps Team
