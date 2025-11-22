# Ejemplo End-to-End: Del Zero al Dashboard

Esta guía te lleva desde cero hasta tener tu pipeline de Big Data completamente funcional con dashboards en vivo.

**Tiempo estimado**: 3-4 horas
**Costo estimado**: ~$2 (4 horas a $0.50/hora)

---

## ✅ Pre-requisitos

- [ ] Cuenta de AWS Academy Learner Lab activada
- [ ] $50 de crédito disponible
- [ ] AWS CLI instalado en tu máquina local
- [ ] Git instalado
- [ ] Kaggle account (para descargar dataset)

---

## Fase 1: Preparación Local (10 minutos)

### 1.1 Configurar AWS CLI

```bash
# Iniciar Learner Lab en AWS Academy
# Copiar las credenciales de AWS Details

# Configurar AWS CLI
aws configure
# AWS Access Key ID: [copiar de AWS Details]
# AWS Secret Access Key: [copiar de AWS Details]
# Default region: us-east-1
# Default output: json

# Verificar
aws sts get-caller-identity
```

### 1.2 Crear SSH Key Pair

```bash
# Crear key pair
aws ec2 create-key-pair \
    --key-name bigd-key \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/bigd-key.pem

chmod 400 ~/.ssh/bigd-key.pem

# Verificar
ls -l ~/.ssh/bigd-key.pem
```

### 1.3 Obtener tu IP pública

```bash
# Obtener tu IP
MY_IP=$(curl -s ifconfig.me)
echo "Mi IP pública: $MY_IP"

# Guardar para después
export MY_IP="$MY_IP/32"
```

### 1.4 Clonar el repositorio

```bash
git clone https://github.com/fernandoramirez1337/bigdata-pipeline.git
cd bigdata-pipeline
```

---

## Fase 2: Crear Cluster en AWS (5 minutos)

### 2.1 Ejecutar script de creación

```bash
cd infrastructure/scripts

# Exportar variables
export KEY_NAME="bigd-key"
export MY_IP="201.230.200.80/32"  # Tu IP del paso 1.3

# Crear cluster
chmod +x create-cluster.sh
./create-cluster.sh
```

**Salida esperada:**
```
========================================
AWS Big Data Cluster - EC2 Creator
========================================

[1/8] Verificando key pair...
✓ Key pair encontrada

[2/8] Obteniendo información de VPC...
✓ VPC ID: vpc-xxxxx
✓ VPC CIDR: 172.31.0.0/16

[3/8] Creando Security Group...
✓ Security Group creado: sg-xxxxx

[4/8] Configurando reglas de firewall...
  ✓ SSH (22) desde 201.230.200.80/32
  ✓ Web UIs (8080-8088) público
  ...

[5/8] Lanzando instancias EC2...
✓ bigdata-master creado: i-xxxxx
✓ bigdata-worker1 creado: i-xxxxx
✓ bigdata-worker2 creado: i-xxxxx
✓ bigdata-storage creado: i-xxxxx

[6/8] Esperando a que las instancias inicien...
✓ Todas las instancias están corriendo

========================================
¡Cluster creado exitosamente!
========================================
```

### 2.2 Guardar información del cluster

```bash
# Ver archivo generado
cat cluster-info.txt

# Guardar IPs en variables (para usarlas después)
MASTER_PRIVATE_IP="172.31.x.x"    # Copiar del archivo
WORKER1_PRIVATE_IP="172.31.x.x"
WORKER2_PRIVATE_IP="172.31.x.x"
STORAGE_PRIVATE_IP="172.31.x.x"

MASTER_PUBLIC_IP="x.x.x.x"        # Copiar del archivo
STORAGE_PUBLIC_IP="x.x.x.x"
```

---

## Fase 3: Configurar /etc/hosts (10 minutos)

### 3.1 Crear script de configuración

```bash
# Crear script temporal
cat > configure-hosts.sh <<EOF
#!/bin/bash
sudo tee -a /etc/hosts <<HOSTS
$MASTER_PRIVATE_IP  master-node bigdata-master
$WORKER1_PRIVATE_IP worker1-node bigdata-worker1
$WORKER2_PRIVATE_IP worker2-node bigdata-worker2
$STORAGE_PRIVATE_IP storage-node bigdata-storage
HOSTS
EOF

chmod +x configure-hosts.sh
```

### 3.2 Ejecutar en todas las instancias

```bash
# Copiar script a todas las EC2
for IP in $MASTER_PUBLIC_IP $WORKER1_PUBLIC_IP $WORKER2_PUBLIC_IP $STORAGE_PUBLIC_IP; do
    echo "Configurando $IP..."
    scp -i ~/.ssh/bigd-key.pem configure-hosts.sh ec2-user@$IP:~
    ssh -i ~/.ssh/bigd-key.pem ec2-user@$IP "bash configure-hosts.sh"
done

echo "✓ /etc/hosts configurado en todas las instancias"
```

---

## Fase 4: Instalar Software (45 minutos)

### 4.1 Actualizar orchestrate-cluster.sh

```bash
# Editar archivo
vim orchestrate-cluster.sh

# Actualizar líneas 25-30 con tus IPs:
MASTER_IP="172.31.x.x"     # Tu IP privada de Master
WORKER1_IP="172.31.x.x"    # Tu IP privada de Worker1
WORKER2_IP="172.31.x.x"    # Tu IP privada de Worker2
STORAGE_IP="172.31.x.x"    # Tu IP privada de Storage
SSH_KEY="~/.ssh/bigd-key.pem"

# Guardar y salir (:wq)
```

### 4.2 Verificar conectividad

```bash
./orchestrate-cluster.sh test-connectivity
```

**Salida esperada:**
```
Testing connectivity to all nodes...
  Master (172.31.x.x): Connected
  Worker1 (172.31.x.x): Connected
  Worker2 (172.31.x.x): Connected
  Storage (172.31.x.x): Connected
```

### 4.3 Instalar todo el software

```bash
# Esto toma 30-45 minutos
./orchestrate-cluster.sh setup-all
```

**Mientras se instala, puedes ir a la Fase 5 en otra terminal**

---

## Fase 5: Preparar Dataset (en paralelo, 1-2 horas)

### 5.1 Instalar Kaggle CLI

```bash
# En una nueva terminal
pip install kaggle

# Configurar API key
# 1. Ir a https://www.kaggle.com/settings/account
# 2. Scroll down → API → Create New Token
# 3. Descargar kaggle.json

mkdir -p ~/.kaggle
mv ~/Downloads/kaggle.json ~/.kaggle/
chmod 600 ~/.kaggle/kaggle.json
```

### 5.2 Descargar dataset (opción: solo 1-2 meses para prueba)

```bash
# Opción A: Dataset completo (12 meses, ~60 GB) - toma tiempo
kaggle datasets download -d elemento/nyc-yellow-taxi-trip-data
unzip nyc-yellow-taxi-trip-data.zip

# Opción B: Solo 2 meses para prueba rápida (recomendado)
kaggle datasets download -d elemento/nyc-yellow-taxi-trip-data -f yellow_tripdata_2015-01.csv
kaggle datasets download -d elemento/nyc-yellow-taxi-trip-data -f yellow_tripdata_2015-02.csv
```

### 5.3 Crear bucket S3 y subir datos

```bash
# Crear bucket con nombre único
BUCKET_NAME="bigdata-taxi-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME

echo "Bucket creado: $BUCKET_NAME"
echo "Guardar este nombre!"

# Subir archivos (esto toma tiempo dependiendo de tu internet)
aws s3 cp yellow_tripdata_2015-01.csv s3://$BUCKET_NAME/nyc-taxi/
aws s3 cp yellow_tripdata_2015-02.csv s3://$BUCKET_NAME/nyc-taxi/

# Verificar
aws s3 ls s3://$BUCKET_NAME/nyc-taxi/
```

---

## Fase 6: Iniciar Cluster (5 minutos)

### 6.1 Iniciar servicios

```bash
# Volver a la terminal con orchestrate-cluster.sh
cd infrastructure/scripts

./orchestrate-cluster.sh start-cluster
```

**Salida esperada:**
```
========================================
Starting Big Data Cluster
========================================

[1/6] Starting Master services...
  Starting Zookeeper...
  Starting Kafka...
  Formatting and starting HDFS...

[2/6] Starting Storage services...

[3/6] Starting Worker services...

[4/6] Creating HDFS directories...

[5/6] Starting Spark cluster...

[6/6] Starting Flink cluster...

========================================
Cluster started successfully!
========================================
```

### 6.2 Verificar estado

```bash
./orchestrate-cluster.sh status
```

### 6.3 Crear Kafka topics

```bash
./orchestrate-cluster.sh create-topics
```

---

## Fase 7: Verificar Web UIs (2 minutos)

Abrir en tu navegador (usar IPs públicas de cluster-info.txt):

### HDFS NameNode
```
http://<MASTER_PUBLIC_IP>:9870
```
**Verificar**: "Live Nodes: 3"

### Spark Master
```
http://<MASTER_PUBLIC_IP>:8080
```
**Verificar**: "Workers (2)"

### Flink Dashboard
```
http://<MASTER_PUBLIC_IP>:8081
```
**Verificar**: "Task Managers (2)"

### Superset
```
http://<STORAGE_PUBLIC_IP>:8088
```
**Login**: admin / admin123

---

## Fase 8: Desplegar Data Producer (10 minutos)

### 8.1 SSH a Master

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_PUBLIC_IP
```

### 8.2 Clonar repo y configurar

```bash
# En Master
git clone https://github.com/fernandoramirez1337/bigdata-pipeline.git
cd bigdata-pipeline/data-producer

# Instalar dependencias
pip3 install -r requirements.txt

# Configurar
vim config.yaml
```

**Actualizar config.yaml:**
```yaml
kafka:
  bootstrap_servers:
    - "172.31.x.x:9092"  # IP privada del Master

dataset:
  source_type: "s3"
  s3:
    bucket: "bigdata-taxi-1234567"  # Tu bucket del paso 5.3
    prefix: "nyc-taxi/"

  months:
    - "2015-01"
    - "2015-02"  # Solo los meses que subiste

replay:
  speed_multiplier: 1000
  max_records_per_second: 1000
  mode: "loop"
```

### 8.3 Iniciar producer

```bash
# Ejecutar en background
nohup python3 src/producer.py --config config.yaml > producer.log 2>&1 &

# Ver logs
tail -f producer.log
```

**Salida esperada:**
```
INFO - Starting data producer
INFO - Replay speed: 1000x
INFO - Processing file: s3://bigdata-taxi-xxx/nyc-taxi/yellow_tripdata_2015-01.csv
INFO - Progress: 10,000 records | Overall rate: 1000.0 rec/s
```

**Presionar Ctrl+C** para salir del tail (el producer sigue corriendo)

### 8.4 Verificar Kafka (en otra terminal SSH)

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_PUBLIC_IP

# Ver mensajes en Kafka
$KAFKA_HOME/bin/kafka-console-consumer.sh \
    --bootstrap-server localhost:9092 \
    --topic taxi-trips-stream \
    --max-messages 5

# Deberías ver registros JSON
```

---

## Fase 9: Desplegar Flink Streaming Job (15 minutos)

### 9.1 Actualizar IPs en código Java (en tu máquina local)

```bash
cd bigdata-pipeline/streaming/flink-jobs/src/main/java/com/bigdata/taxi

vim ZoneAggregationJob.java
```

**Actualizar líneas 15-17:**
```java
private static final String KAFKA_BROKERS = "172.31.x.x:9092";  // Master IP privada
private static final String JDBC_URL = "jdbc:postgresql://172.31.x.x:5432/bigdata_taxi";  // Storage IP privada
```

### 9.2 Compilar

```bash
cd ../../../../../../..  # Volver a streaming/
bash build.sh
```

**Salida esperada:**
```
Building Flink Streaming Jobs...
[INFO] Building taxi-streaming-jobs 1.0-SNAPSHOT
[INFO] BUILD SUCCESS
Build successful!
JAR location: target/taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

### 9.3 Copiar JAR a Master

```bash
scp -i ~/.ssh/bigd-key.pem \
    flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar \
    ec2-user@$MASTER_PUBLIC_IP:~/
```

### 9.4 Desplegar en Flink

```bash
# SSH a Master
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_PUBLIC_IP

# Desplegar job
flink run taxi-streaming-jobs-1.0-SNAPSHOT.jar
```

**Salida esperada:**
```
Job has been submitted with JobID xxxxxxxxxxxxx
```

### 9.5 Verificar en Flink UI

```
http://<MASTER_PUBLIC_IP>:8081
```

Deberías ver:
- **Running Jobs**: 1
- **Job Name**: "NYC Taxi Zone Aggregation Job"
- **Status**: RUNNING

---

## Fase 10: Verificar Datos en PostgreSQL (5 minutos)

### 10.1 SSH a Storage

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$STORAGE_PUBLIC_IP
```

### 10.2 Consultar datos

```bash
# Conectar a PostgreSQL
psql -U bigdata -d bigdata_taxi

# Ver registros recientes
SELECT
    zone_id,
    window_start,
    trip_count,
    total_revenue,
    avg_fare
FROM real_time_zones
ORDER BY window_start DESC
LIMIT 10;

# Ver resumen
SELECT
    COUNT(*) as total_windows,
    SUM(trip_count) as total_trips,
    MIN(window_start) as first_window,
    MAX(window_start) as last_window
FROM real_time_zones;

# Salir
\q
```

**Si ves datos**: ✅ **¡El pipeline streaming está funcionando!**

---

## Fase 11: Configurar Dashboard en Superset (15 minutos)

### 11.1 Acceder a Superset

```
http://<STORAGE_PUBLIC_IP>:8088
```
- **Usuario**: admin
- **Password**: admin123

### 11.2 Conectar base de datos

1. Click en **+ → Data → Connect database**
2. Seleccionar: **PostgreSQL**
3. Configurar:
   ```
   Host: localhost
   Port: 5432
   Database: bigdata_taxi
   Username: bigdata
   Password: bigdata123
   ```
4. **Test Connection** → Debe decir "OK"
5. **Connect**

### 11.3 Crear Dataset

1. **+ → Data → Create dataset**
2. Database: **bigdata_taxi**
3. Schema: **public**
4. Table: **real_time_zones**
5. **Create dataset and create chart**

### 11.4 Crear primer chart: Trips/Minute

1. Visualization Type: **Line Chart**
2. Time Column: **window_start**
3. Metrics: **SUM(trip_count)**
4. Time Range: **Last hour**
5. Run Query

Deberías ver una línea mostrando viajes por minuto!

### 11.5 Crear Dashboard

1. **+ → Dashboard**
2. Nombre: "NYC Taxi - Real Time"
3. Arrastra el chart creado
4. **Save**

### 11.6 Configurar Auto-refresh

1. En el dashboard, click en **⋮** (tres puntos)
2. **Settings**
3. **Auto-refresh**  10 seconds
4. **Save**

---

## Fase 12: Desplegar Spark Batch Job (10 minutos)

### 12.1 SSH a Master

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@$MASTER_PUBLIC_IP
cd bigdata-pipeline/batch/spark-jobs
```

### 12.2 Actualizar IPs

```bash
vim daily_summary.py
```

**Actualizar líneas 117-119:**
```python
HDFS_INPUT = "hdfs://172.31.x.x:9000/data/taxi/raw"  # Master IP
POSTGRES_URL = "jdbc:postgresql://172.31.x.x:5432/bigdata_taxi"  # Storage IP
```

### 12.3 Ejecutar job de prueba

```bash
$SPARK_HOME/bin/spark-submit \
    --master spark://172.31.x.x:7077 \
    --driver-memory 2g \
    --executor-memory 4g \
    --executor-cores 2 \
    --packages org.postgresql:postgresql:42.6.0 \
    daily_summary.py
```

---

## ✅ Verificación Final

### Checklist de Funcionamiento

- [ ] **Data Producer**: Logs muestran "Overall rate: ~1000 rec/s"
- [ ] **Kafka**: Mensajes visibles con console-consumer
- [ ] **Flink**: Job en estado RUNNING en UI
- [ ] **PostgreSQL**: Tabla real_time_zones tiene datos
- [ ] **Superset**: Dashboard muestra datos actualizándose
- [ ] **HDFS**: 3 DataNodes activos
- [ ] **Spark**: 2 Workers registrados

### Comandos de verificación rápida

```bash
# Estado del cluster
./orchestrate-cluster.sh status

# Ver logs del producer
ssh ec2-user@$MASTER_PUBLIC_IP "tail -20 bigdata-pipeline/data-producer/producer.log"

# Contar registros en PostgreSQL
ssh ec2-user@$STORAGE_PUBLIC_IP "psql -U bigdata -d bigdata_taxi -c 'SELECT COUNT(*) FROM real_time_zones;'"
```

---

## 🎉 ¡Éxito!

Si llegaste aquí, tienes:

✅ **Cluster de 4 EC2** operativo
✅ **Pipeline de streaming** con Flink procesando datos en tiempo real
✅ **Dashboard en Superset** actualizándose cada 10 segundos
✅ **Procesamiento batch** con Spark
✅ **Almacenamiento distribuido** en HDFS

### Próximos pasos

1. Crear más dashboards en Superset
2. Agregar más jobs de Spark batch
3. Monitorear costos en AWS
4. Tomar screenshots para presentación
5. Crear EBS snapshots para backup

---

## 🛑 Apagar el Cluster (Importante!)

**Cuando termines de usar el cluster:**

```bash
# Detener servicios
./orchestrate-cluster.sh stop-cluster

# Ir a AWS Console → EC2 → Instances
# Seleccionar las 4 instancias
# Instance State → Stop instance

# IMPORTANTE: NO terminar (Terminate), solo detener (Stop)
```

**Costos al estar detenido:**
- EC2: $0/hora (no se cobra)
- EBS: ~$0.036/hora (~$0.86/día por 550 GB)

---

## 📊 Métricas de Este Ejemplo

- **Tiempo total**: ~3-4 horas
- **Costo**: ~$2-3
- **Datos procesados**: 2 meses (~10-20 GB)
- **Throughput**: ~1000 eventos/segundo
- **Latencia**: <5 segundos end-to-end

---

¿Preguntas? Ver [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) o abrir un issue en GitHub.
