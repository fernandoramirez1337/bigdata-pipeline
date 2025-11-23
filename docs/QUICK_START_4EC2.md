# Quick Start - 4 EC2 Configuration

## Checklist de Deployment

### Fase 1: Preparación (15 min)

#### ✅ AWS Academy Setup
- [ ] Iniciar AWS Learner Lab
- [ ] Confirmar región: **us-east-1 (Virginia)**
- [ ] Verificar presupuesto disponible ($50)
- [ ] Descargar o crear SSH Key Pair

#### ✅ Security Group
Crear Security Group "bigdata-cluster-sg":

```
Inbound Rules:
┌──────────────┬──────────┬───────────────────┬─────────────────┐
│ Type         │ Port     │ Source            │ Description     │
├──────────────┼──────────┼───────────────────┼─────────────────┤
│ SSH          │ 22       │ My IP             │ SSH access      │
│ Custom TCP   │ 2181     │ 10.0.0.0/16       │ Zookeeper       │
│ Custom TCP   │ 5432     │ 10.0.0.0/16       │ PostgreSQL      │
│ Custom TCP   │ 6123     │ 10.0.0.0/16       │ Flink RPC       │
│ Custom TCP   │ 7077     │ 10.0.0.0/16       │ Spark Master    │
│ Custom TCP   │ 8080-8088│ 0.0.0.0/0         │ Web UIs         │
│ Custom TCP   │ 9000     │ 10.0.0.0/16       │ HDFS NameNode   │
│ Custom TCP   │ 9092     │ 10.0.0.0/16       │ Kafka           │
│ Custom TCP   │ 9870     │ 0.0.0.0/0         │ HDFS Web UI     │
│ All TCP      │ 0-65535  │ sg-xxxxx (mismo)  │ Inter-cluster   │
└──────────────┴──────────┴───────────────────┴─────────────────┘
```

---

### Fase 2: Lanzar EC2 Instances (20 min)

#### EC2-1: Master Node

```yaml
Name: bigdata-master
AMI: Amazon Linux 2023
Instance Type: t3.large
vCPU: 2
RAM: 8 GB
Storage: 100 GB gp3
Security Group: bigdata-cluster-sg
Key Pair: <your-key>
```

**User Data (opcional):**
```bash
#!/bin/bash
hostnamectl set-hostname master-node
```

#### EC2-2: Worker Node 1

```yaml
Name: bigdata-worker1
AMI: Amazon Linux 2023
Instance Type: t3.xlarge
vCPU: 4
RAM: 16 GB
Storage: 200 GB gp3
Security Group: bigdata-cluster-sg
Key Pair: <your-key>
```

**User Data:**
```bash
#!/bin/bash
hostnamectl set-hostname worker1-node
```

#### EC2-3: Worker Node 2

```yaml
Name: bigdata-worker2
AMI: Amazon Linux 2023
Instance Type: t3.xlarge
vCPU: 4
RAM: 16 GB
Storage: 200 GB gp3
Security Group: bigdata-cluster-sg
Key Pair: <your-key>
```

**User Data:**
```bash
#!/bin/bash
hostnamectl set-hostname worker2-node
```

#### EC2-4: Storage Node

```yaml
Name: bigdata-storage
AMI: Amazon Linux 2023
Instance Type: t3.large
vCPU: 2
RAM: 8 GB
Storage: 150 GB gp3
Security Group: bigdata-cluster-sg
Key Pair: <your-key>
```

**User Data:**
```bash
#!/bin/bash
hostnamectl set-hostname storage-node
```

---

### Fase 3: Configuración de Red (10 min)

#### ✅ Anotar IPs Privadas

Después de lanzar las instancias, anotar las IPs:

```
EC2-1 Master:  Private IP: ________________  Public IP: ________________
EC2-2 Worker1: Private IP: ________________  Public IP: ________________
EC2-3 Worker2: Private IP: ________________  Public IP: ________________
EC2-4 Storage: Private IP: ________________  Public IP: ________________
```

#### ✅ Configurar /etc/hosts en TODAS las instancias

SSH a cada instancia y ejecutar:

```bash
# Reemplazar con tus IPs reales
MASTER_IP="10.0.x.x"
WORKER1_IP="10.0.x.x"
WORKER2_IP="10.0.x.x"
STORAGE_IP="10.0.x.x"

sudo tee -a /etc/hosts <<EOF
$MASTER_IP  master-node bigdata-master
$WORKER1_IP worker1-node bigdata-worker1
$WORKER2_IP worker2-node bigdata-worker2
$STORAGE_IP storage-node bigdata-storage
EOF
```

---

### Fase 4: Instalación Automatizada (30-45 min)

#### ✅ En tu máquina local

```bash
# 1. Clonar repositorio
git clone https://github.com/fernandoramirez1337/bigdata-pipeline.git
cd bigdata-pipeline

# 2. Actualizar orchestrate-cluster.sh
vim infrastructure/scripts/orchestrate-cluster.sh

# Actualizar estas líneas (líneas 25-28):
MASTER_IP="10.0.x.x"      # Tu IP privada de EC2-1
WORKER1_IP="10.0.x.x"     # Tu IP privada de EC2-2
WORKER2_IP="10.0.x.x"     # Tu IP privada de EC2-3
STORAGE_IP="10.0.x.x"     # Tu IP privada de EC2-4

# También actualizar:
SSH_KEY="~/.ssh/tu-key.pem"

# 3. Dar permisos a scripts
chmod +x infrastructure/scripts/*.sh
chmod 400 ~/.ssh/tu-key.pem

# 4. Probar conectividad
./infrastructure/scripts/orchestrate-cluster.sh test-connectivity

# 5. Instalar en todas las instancias (esto toma ~30-45 min)
./infrastructure/scripts/orchestrate-cluster.sh setup-all
```

**Mientras se instala, prepara el dataset...**

---

### Fase 5: Preparar Dataset (1-2 horas en paralelo)

#### ✅ Opción A: Dataset completo (Recomendado)

```bash
# 1. Crear cuenta en Kaggle
# 2. Obtener API key: https://www.kaggle.com/settings/account

# 3. Instalar Kaggle CLI
pip install kaggle

# 4. Configurar credenciales
mkdir -p ~/.kaggle
# Copiar kaggle.json a ~/.kaggle/

# 5. Descargar dataset
kaggle datasets download -d elemento/nyc-yellow-taxi-trip-data
unzip nyc-yellow-taxi-trip-data.zip

# 6. Crear S3 bucket (desde AWS Console o CLI)
aws s3 mb s3://bigdata-taxi-dataset-<TU-ID-UNICO>

# 7. Subir archivos a S3
for file in yellow_tripdata_2015-*.csv; do
    aws s3 cp $file s3://bigdata-taxi-dataset-<TU-ID>/nyc-taxi/
done
```

#### ✅ Opción B: Dataset de prueba (Rápido)

```bash
# Solo descargar 1-2 meses para pruebas
# Esto ahorra tiempo y costos
kaggle datasets download -d elemento/nyc-yellow-taxi-trip-data -f yellow_tripdata_2015-01.csv
```

---

### Fase 6: Iniciar Cluster (5 min)

```bash
# Desde tu máquina local
./infrastructure/scripts/orchestrate-cluster.sh start-cluster

# Verificar estado
./infrastructure/scripts/orchestrate-cluster.sh status

# Crear Kafka topics
./infrastructure/scripts/orchestrate-cluster.sh create-topics
```

---

### Fase 7: Verificar Instalación (5 min)

#### ✅ Web UIs

Abrir en navegador (usar Public IPs):

- [ ] **HDFS**: http://\<MASTER-PUBLIC-IP\>:9870
  - ✅ Debe mostrar 3 DataNodes vivos

- [ ] **Spark**: http://\<MASTER-PUBLIC-IP\>:8080
  - ✅ Debe mostrar 2 Workers activos

- [ ] **Flink**: http://\<MASTER-PUBLIC-IP\>:8081
  - ✅ Debe mostrar 2 TaskManagers disponibles

- [ ] **Superset**: http://\<STORAGE-PUBLIC-IP\>:8088
  - ✅ Login: admin / admin123

#### ✅ Verificar HDFS desde Master

```bash
ssh -i tu-key.pem ec2-user@<MASTER-PUBLIC-IP>

# Ver DataNodes
hdfs dfsadmin -report

# Debe mostrar:
# Live datanodes (3):
# - worker1-node:9866
# - worker2-node:9866
# - storage-node:9866
```

---

### Fase 8: Desplegar Data Producer (10 min)

#### ✅ SSH a Master

```bash
ssh -i tu-key.pem ec2-user@<MASTER-PUBLIC-IP>

# Clonar repo
git clone https://github.com/fernandoramirez1337/bigdata-pipeline.git
cd bigdata-pipeline/data-producer

# Instalar dependencias
pip3 install -r requirements.txt

# Configurar config.yaml
vim config.yaml
```

**Actualizar en config.yaml:**

```yaml
kafka:
  bootstrap_servers:
    - "10.0.x.x:9092"  # IP privada del Master

dataset:
  source_type: "s3"  # o "local" si descargaste local
  s3:
    bucket: "bigdata-taxi-dataset-<TU-ID>"
    prefix: "nyc-taxi/"
```

**Iniciar producer:**

```bash
# Ejecutar en background
nohup python3 src/producer.py --config config.yaml > producer.log 2>&1 &

# Ver logs en tiempo real
tail -f producer.log

# Deberías ver:
# INFO - Processing file: ...
# INFO - Progress: 10,000 records | Overall rate: 1000.0 rec/s
```

---

### Fase 9: Desplegar Flink Streaming Job (15 min)

#### ✅ Actualizar IPs en código Java

```bash
# En tu máquina local
cd bigdata-pipeline/streaming/flink-jobs/src/main/java/com/bigdata/taxi

# Editar ZoneAggregationJob.java
vim ZoneAggregationJob.java
```

**Líneas a actualizar (15-17):**

```java
private static final String KAFKA_BROKERS = "10.0.x.x:9092";  // Master IP
private static final String JDBC_URL = "jdbc:postgresql://10.0.x.x:5432/bigdata_taxi";  // Storage IP
```

#### ✅ Compilar y desplegar

```bash
# En tu máquina local
cd streaming
bash build.sh

# Copiar JAR a Master
scp -i ~/.ssh/tu-key.pem \
    flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar \
    ec2-user@<MASTER-PUBLIC-IP>:~/

# SSH a Master y desplegar
ssh -i tu-key.pem ec2-user@<MASTER-PUBLIC-IP>

flink run taxi-streaming-jobs-1.0-SNAPSHOT.jar

# Verificar en UI: http://<MASTER-PUBLIC-IP>:8081
# Debería aparecer "NYC Taxi Zone Aggregation Job" como RUNNING
```

---

### Fase 10: Configurar Spark Batch Jobs (10 min)

#### ✅ SSH a Master

```bash
cd bigdata-pipeline/batch/spark-jobs

# Actualizar IPs en daily_summary.py (líneas 117-119)
vim daily_summary.py
```

**Actualizar:**

```python
HDFS_INPUT = "hdfs://10.0.x.x:9000/data/taxi/raw"  # Master IP
POSTGRES_URL = "jdbc:postgresql://10.0.x.x:5432/bigdata_taxi"  # Storage IP
```

#### ✅ Ejecutar job de prueba

```bash
# Ejecutar manualmente
$SPARK_HOME/bin/spark-submit \
    --master spark://10.0.x.x:7077 \
    --driver-memory 2g \
    --executor-memory 4g \
    --executor-cores 2 \
    --packages org.postgresql:postgresql:42.6.0 \
    daily_summary.py

# Si funciona, configurar cron para ejecución diaria
crontab -e

# Agregar:
0 2 * * * $SPARK_HOME/bin/spark-submit --master spark://10.0.x.x:7077 --packages org.postgresql:postgresql:42.6.0 /home/ec2-user/bigdata-pipeline/batch/spark-jobs/daily_summary.py >> /var/log/bigdata/spark-daily.log 2>&1
```

---

### Fase 11: Configurar Superset Dashboards (20 min)

#### ✅ Acceder a Superset

```
URL: http://<STORAGE-PUBLIC-IP>:8088
User: admin
Pass: admin123
```

#### ✅ Conectar Database

1. Data → Databases → + Database
2. Seleccionar: **PostgreSQL**
3. Configurar:
   ```
   Host: localhost
   Port: 5432
   Database: bigdata_taxi
   Username: bigdata
   Password: bigdata123
   ```
4. Test Connection → Save

#### ✅ Crear Datasets

Data → Datasets → + Dataset

Agregar las siguientes tablas:
- [ ] real_time_zones
- [ ] real_time_global
- [ ] daily_summary
- [ ] hourly_zone_stats
- [ ] route_analysis

#### ✅ Crear Dashboard de Tiempo Real

1. Dashboards → + Dashboard
2. Nombre: "NYC Taxi - Real Time"
3. Agregar Charts:

**Chart 1: Big Number - Active Trips**
```sql
SELECT SUM(trip_count)
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '1 minute'
```

**Chart 2: Line Chart - Trips/Minute**
```sql
SELECT window_start, SUM(trip_count) as trips
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '30 minutes'
GROUP BY window_start
ORDER BY window_start
```

**Chart 3: Bar Chart - Top 10 Zones**
```sql
SELECT zone_id, SUM(trip_count) as trips
FROM real_time_zones
WHERE window_start > NOW() - INTERVAL '5 minutes'
GROUP BY zone_id
ORDER BY trips DESC
LIMIT 10
```

4. Configurar Auto-Refresh: 10 segundos

---

## Verificación Final

### ✅ Checklist de Funcionamiento

- [ ] **Data Producer**: Logs muestran registros enviados a Kafka
- [ ] **Kafka**: Topic "taxi-trips-stream" tiene mensajes
- [ ] **Flink**: Job está RUNNING, procesando eventos
- [ ] **PostgreSQL**: Tabla real_time_zones tiene datos recientes
- [ ] **Superset**: Dashboard muestra datos en tiempo real
- [ ] **HDFS**: Datos siendo escritos a /data/taxi/raw
- [ ] **Spark**: Jobs batch ejecutan correctamente

### ✅ Comandos de Verificación

```bash
# Ver mensajes en Kafka
ssh ec2-user@<MASTER-IP>
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic taxi-trips-stream \
    --max-messages 5

# Ver datos en PostgreSQL
ssh ec2-user@<STORAGE-IP>
psql -U bigdata -d bigdata_taxi -c "SELECT COUNT(*) FROM real_time_zones;"

# Ver archivos en HDFS
ssh ec2-user@<MASTER-IP>
hdfs dfs -ls -R /data/taxi/
```

---

## Troubleshooting Rápido

### Problema: No hay datos en Superset

```bash
# 1. Verificar producer
ssh ec2-user@<MASTER-IP>
ps aux | grep producer
tail -f bigdata-pipeline/data-producer/producer.log

# 2. Verificar Kafka
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic taxi-trips-stream \
    --from-beginning --max-messages 10

# 3. Verificar Flink job
http://<MASTER-IP>:8081

# 4. Ver logs de Flink
tail -f /opt/bigdata/flink/log/flink-*-taskexecutor-*.log
```

### Problema: Servicios no inician

```bash
# Ver status de todos los servicios
./infrastructure/scripts/orchestrate-cluster.sh status

# Reiniciar cluster
./infrastructure/scripts/orchestrate-cluster.sh stop-cluster
./infrastructure/scripts/orchestrate-cluster.sh start-cluster
```

---

## Costos y Optimización

### Costo por Hora
- t3.large (2x): $0.1664/hora
- t3.xlarge (2x): $0.3328/hora
- **Total**: ~$0.50/hora

### Estrategia con $50
- **Desarrollo**: 10 horas (~$5)
- **Testing**: 10 horas (~$5)
- **Demo/Producción**: 20 horas (~$10)
- **Buffer**: 60 horas (~$30)

### Apagar instancias cuando no se usen

```bash
# Detener cluster
./infrastructure/scripts/orchestrate-cluster.sh stop-cluster

# En AWS Console: Stop Instances (NO Terminate!)
# Esto detiene cobros de EC2, solo pagas storage (~$0.10/GB/mes)
```

---

## Próximos Pasos

1. ✅ Monitorear pipeline por 24 horas
2. ✅ Ajustar parámetros si es necesario
3. ✅ Crear EBS snapshots para backup
4. ✅ Preparar presentación/demo
5. ✅ Documentar resultados y métricas

---

## Enlaces Útiles

- **Repositorio**: https://github.com/fernandoramirez1337/bigdata-pipeline
- **Plan Completo**: [PLAN_ARQUITECTURA.md](../PLAN_ARQUITECTURA.md)
- **Guía Detallada**: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **Dataset Kaggle**: https://www.kaggle.com/datasets/elemento/nyc-yellow-taxi-trip-data

---

**¡Éxito con tu proyecto! 🚀**
