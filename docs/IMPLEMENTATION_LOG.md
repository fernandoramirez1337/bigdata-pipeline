# Log de Implementación - Big Data Pipeline AWS

**Fecha de inicio**: 20 de Noviembre, 2025
**Cluster**: 4 EC2 instances en AWS Free Tier
**Objetivo**: Pipeline completo de Big Data para NYC Taxi Dataset (165M registros)

---

## Tabla de Contenidos

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Paso a Paso Completado](#paso-a-paso-completado)
3. [Problemas Encontrados y Soluciones](#problemas-encontrados-y-soluciones)
4. [Estado Actual del Cluster](#estado-actual-del-cluster)
5. [Próximos Pasos](#próximos-pasos)
6. [Configuración Final del Cluster](#configuración-final-del-cluster)

---

## Resumen Ejecutivo

### ✅ Completado

- **Infraestructura EC2**: 4 instancias creadas y configuradas
- **Networking**: Security Group, /etc/hosts, conectividad SSH
- **Scripts de automatización**: Actualizados para AWS Free Tier
- **Instalación base**: Java 11 Amazon Corretto, Python, utilidades
- **Fix crítico**: Resuelto conflicto de paquete curl en Amazon Linux 2023

### ⏳ En Progreso

- **Instalación de software distribuido**: Kafka, Zookeeper, Flink, Spark, HDFS, PostgreSQL, Superset
- **Proceso actual**: `./orchestrate-cluster.sh setup-all` ejecutándose (~30-45 minutos)

### 📋 Pendiente

- Inicialización de servicios
- Configuración de Kafka topics
- Despliegue de jobs Flink y Spark
- Configuración de Superset dashboards
- Ingesta de datos NYC Taxi

---

## Paso a Paso Completado

### Fase 1: Preparación de Infraestructura ✅

#### 1.1 Creación del Cluster EC2 (14:40 UTC)

```bash
cd bigdata-pipeline/infrastructure/scripts
./create-cluster.sh
```

**Resultado**: 4 instancias EC2 creadas exitosamente en AWS Free Tier

| Instancia | ID | Tipo | IP Privada | IP Pública | Volumen EBS |
|-----------|-----|------|-----------|------------|-------------|
| Master | i-095692309cc67a77e | t3.small | 172.31.72.49 | 44.210.18.254 | 30 GB |
| Worker1 | i-09a02241a47abc50d | c7i-flex.large | 172.31.70.167 | 44.221.77.132 | 30 GB |
| Worker2 | i-0d0535e69242b7db5 | c7i-flex.large | 172.31.15.51 | 3.219.215.11 | 30 GB |
| Storage | i-05ebe42a3698b6b71 | m7i-flex.large | 172.31.31.171 | 98.88.249.180 | 30 GB |

**Componentes por instancia**:
- **Master**: Kafka, Zookeeper, Flink JobManager, Spark Master, HDFS NameNode
- **Worker1**: Flink TaskManager, Spark Worker, HDFS DataNode
- **Worker2**: Flink TaskManager, Spark Worker, HDFS DataNode
- **Storage**: PostgreSQL, Superset, HDFS DataNode, S3 connector

**Tipos de instancia**:
- t3.small: 2 vCPUs, 2 GB RAM (Master - coordinación)
- c7i-flex.large: 2 vCPUs, 4 GB RAM (Workers - procesamiento)
- m7i-flex.large: 2 vCPUs, 8 GB RAM (Storage - base de datos)

#### 1.2 Configuración de Red ✅

**Security Group**: `bigdata-cluster-sg` creado con reglas:

| Puerto(s) | Protocolo | Origen | Servicio |
|-----------|-----------|--------|----------|
| 22 | TCP | IP del usuario | SSH |
| 2181 | TCP | VPC | Zookeeper |
| 5432 | TCP | VPC | PostgreSQL |
| 6123 | TCP | VPC | Flink RPC |
| 7077 | TCP | VPC | Spark Master |
| 8080-8088 | TCP | 0.0.0.0/0 | Web UIs (Spark, Flink, Superset) |
| 9000 | TCP | VPC | HDFS NameNode RPC |
| 9092 | TCP | VPC | Kafka Broker |
| 9870 | TCP | 0.0.0.0/0 | HDFS Web UI |
| All | All | Security Group | Comunicación inter-cluster |

#### 1.3 Configuración de /etc/hosts ✅

Ejecutado en las 4 instancias:

```bash
sudo tee -a /etc/hosts <<EOF
172.31.72.49  master-node bigdata-master
172.31.70.167 worker1-node bigdata-worker1
172.31.15.51  worker2-node bigdata-worker2
172.31.31.171 storage-node bigdata-storage
EOF
```

**Verificación**: Ping exitoso entre todas las instancias usando hostnames.

#### 1.4 Actualización de orchestrate-cluster.sh ✅

Archivo actualizado con IPs públicas para SSH desde máquina local:

```bash
# infrastructure/scripts/orchestrate-cluster.sh
MASTER_IP="44.210.18.254"
WORKER1_IP="44.221.77.132"
WORKER2_IP="3.219.215.11"
STORAGE_IP="98.88.249.180"
```

**Nota importante**: Se usan IPs públicas para SSH desde local, pero los servicios internos usan IPs privadas.

---

### Fase 2: Instalación de Software Base ✅

#### 2.1 Primer Intento de Instalación (14:42 UTC) ❌

**Comando ejecutado**:
```bash
./orchestrate-cluster.sh setup-all
```

**Resultado**: FALLO - Error de paquete curl

**Error encontrado** (en las 4 instancias):
```
Error:
 Problem: problem with installed package curl-minimal-8.5.0-1.amzn2023.0.4.x86_64
  - package curl-minimal-8.5.0-1.amzn2023.0.4.x86_64 from @System conflicts
    with curl provided by curl-7.87.0-2.amzn2023.0.2.x86_64 from amazonlinux
  - conflicting requests
```

**Análisis del problema**:
- Amazon Linux 2023 viene con `curl-minimal` pre-instalado
- El script `common-setup.sh` intentaba instalar el paquete completo `curl`
- Ambos paquetes proveen funcionalidad curl pero son mutuamente excluyentes
- El instalador de paquetes (dnf) no puede resolver este conflicto automáticamente

**Impacto**:
- Instalación bloqueada en paso [3/8] "Installing essential utilities"
- Todos los pasos subsecuentes no se ejecutaron
- Las 4 instancias quedaron con instalación parcial:
  - ✅ Java 11 Amazon Corretto instalado
  - ✅ Variables de entorno configuradas
  - ❌ Utilidades esenciales: instalación incompleta
  - ❌ Directorios y configuraciones: no creados
  - ❌ Software Big Data: no instalado

#### 2.2 Resolución del Problema (14:55 UTC) ✅

**Archivo modificado**: `infrastructure/scripts/common-setup.sh`

**Cambio realizado** (línea 44):
```diff
 # Instalar utilidades esenciales
 echo -e "${GREEN}[3/8] Installing essential utilities...${NC}"
 sudo yum install -y \
     wget \
-    curl \
     tar \
     gzip \
     git \
```

**Justificación**:
- `wget` ya está siendo instalado y provee funcionalidad similar a curl
- `curl-minimal` ya está pre-instalado en Amazon Linux 2023
- Remover curl del script elimina el conflicto sin pérdida de funcionalidad

**Commit**:
```bash
git commit -m "Fix curl package conflict on Amazon Linux 2023"
git push -u origin claude/aws-ec2-distributed-plan-018mA2bSY4uvxcLBuHq1CkDS
```

Commit ID: `4099a6b`

#### 2.3 Segunda Ejecución - Instalación Exitosa (14:57 UTC) ⏳

**Comando ejecutado**:
```bash
git pull origin claude/aws-ec2-distributed-plan-018mA2bSY4uvxcLBuHq1CkDS
./orchestrate-cluster.sh setup-all
```

**Progreso de instalación**:

##### Common Setup (Todas las instancias) ✅

**Step [1/8] - System Update**: ✅ Completado
- Paquetes del sistema actualizados
- Advertencia: Versión más reciente de Amazon Linux disponible (no crítico)

**Step [2/8] - Java Installation**: ✅ Completado
- Instalado: `java-11-amazon-corretto-1:11.0.25+9-1.amzn2023.x86_64`
- Instalado: `java-11-amazon-corretto-devel`
- JAVA_HOME configurado: `/usr/lib/jvm/java-11-amazon-corretto`
- Verificación: OpenJDK 11.0.25 funcionando correctamente

**Step [3/8] - Essential Utilities**: ✅ Completado
```
Instalados:
- git 2.40.1
- htop 3.2.1
- nmap-ncat (nc)
- python3-pip 21.3.1
- telnet
- tmux 3.2a
- wget, tar, gzip, vim, net-tools, python3 (ya estaban instalados)
```

**Step [4/8] - Directory Creation**: ✅ Completado
```
Directorios creados:
- /opt/bigdata (instalación de software)
- /data/kafka, /data/zookeeper, /data/hdfs, /data/flink, /data/spark, /data/postgresql
- /var/log/bigdata (logs centralizados)
```

**Step [5/8] - System Limits**: ✅ Completado
```
Configurado en /etc/security/limits.conf:
- nofile (archivos abiertos): 65536 soft/hard
- nproc (procesos): 32768 soft/hard
```

**Step [6/8] - Transparent Huge Pages**: ✅ Completado
```
Deshabilitado THP para mejor rendimiento en Big Data:
- /sys/kernel/mm/transparent_hugepage/enabled: never
- /sys/kernel/mm/transparent_hugepage/defrag: never
```

**Step [7/8] - Swappiness**: ✅ Completado
```
vm.swappiness configurado a 10 (reducir uso de swap)
```

**Step [8/8] - Python Packages**: ✅ Completado
```
Instalados:
- pip 25.3 (actualizado desde 21.3.1)
- kafka-python 2.0.2
- pandas 2.0.3
- pyarrow 12.0.1
- boto3 1.28.25 (AWS SDK)
- psycopg2-binary 2.9.7 (PostgreSQL driver)
- pyyaml 6.0.1
- numpy 2.0.2 (dependencia de pandas)
- python-dateutil 2.9.0.post0
```

**Advertencia menor**:
```
ERROR: pip's dependency resolver does not currently take into account all
the packages that are installed. This behaviour is the source of the
following dependency conflicts.
awscli 2.15.30 requires python-dateutil<=2.8.2,>=2.1, but you have
python-dateutil 2.9.0.post0 which is incompatible.
```
- **Impacto**: Bajo - AWS CLI no es crítico para el pipeline
- **Acción**: No requiere corrección inmediata

##### Master Node Setup ⏳ EN PROGRESO

**[1/6] - Apache Zookeeper 3.8.3**: ✅ Completado (2 minutos)
```bash
wget https://archive.apache.org/dist/zookeeper/zookeeper-3.8.3/apache-zookeeper-3.8.3-bin.tar.gz
# Descargado: 14.8 MB
# Velocidad promedio: 120 KB/s
```

**[2/6] - Apache Kafka 3.6.0**: ⏳ EN PROGRESO (~7% completado)
```bash
wget https://archive.apache.org/dist/kafka/3.6.0/kafka_2.13-3.6.0.tgz
# Tamaño total: 108 MB
# Velocidad promedio: ~150 KB/s
# Tiempo estimado: 11-12 minutos
```

**Pendiente en Master**:
- [3/6] Apache Flink 1.18.0
- [4/6] Apache Spark 3.5.0
- [5/6] Hadoop HDFS 3.3.6
- [6/6] Configuraciones y servicios

##### Worker Nodes Setup ⏸️ ESPERANDO

Setup de Worker1 y Worker2 iniciará después de completar Master.

**Componentes a instalar**:
- Apache Flink 1.18.0 (TaskManager)
- Apache Spark 3.5.0 (Worker)
- Hadoop HDFS 3.3.6 (DataNode)

##### Storage Node Setup ⏸️ ESPERANDO

Setup de Storage iniciará después de completar Workers.

**Componentes a instalar**:
- PostgreSQL 15
- Apache Superset 3.1.0
- Hadoop HDFS 3.3.6 (DataNode)
- AWS CLI v2
- Scripts de sincronización S3

---

## Problemas Encontrados y Soluciones

### 1. Conflicto de Paquete curl ❌ → ✅

**Problema**:
```
Error: package curl-minimal conflicts with curl
```

**Causa Raíz**:
- Amazon Linux 2023 incluye `curl-minimal` por defecto
- El script intentaba instalar `curl` completo
- DNF no puede tener ambos paquetes simultáneamente

**Solución Implementada**:
- Removido `curl` de la lista de instalación en `common-setup.sh`
- `wget` provee funcionalidad equivalente para descargas
- `curl-minimal` ya disponible para operaciones básicas

**Archivos modificados**:
- `infrastructure/scripts/common-setup.sh` (línea 44)

**Commit**: 4099a6b

**Estado**: ✅ RESUELTO

### 2. Velocidad de Descarga Lenta ⚠️

**Observación**:
- Descargas de Apache Archive a ~120-150 KB/s
- Zookeeper (14.8 MB): ~2 minutos
- Kafka (108 MB): ~11-12 minutos estimados

**Causa**:
- Limitaciones de ancho de banda de instancias t3.small/c7i-flex.large
- Apache Archive puede tener throttling
- Latencia entre AWS us-east-1 y servidores de Apache

**Impacto**:
- Proceso de instalación completo tardará 30-45 minutos
- No afecta funcionamiento posterior del cluster
- Solo impacta tiempo de setup inicial

**Mitigación**:
- Considerar para futuras implementaciones:
  - Pre-descargar archives y subirlos a S3
  - Usar AMI personalizada con software pre-instalado
  - Aprovechar mirrors más cercanos geográficamente

**Estado**: ⚠️ ACEPTADO (no crítico)

---

## Estado Actual del Cluster

### Timestamp: 20 Nov 2025, 15:05 UTC

#### Resumen de Estado

| Componente | Master | Worker1 | Worker2 | Storage | Estado |
|------------|--------|---------|---------|---------|--------|
| **Common Setup** | ✅ | ✅ | ✅ | ✅ | Completado |
| Java 11 | ✅ | ✅ | ✅ | ✅ | Instalado |
| Python 3.9 + packages | ✅ | ✅ | ✅ | ✅ | Instalado |
| Directorios | ✅ | ✅ | ✅ | ✅ | Creados |
| **Specific Setup** | ⏳ | ⏸️ | ⏸️ | ⏸️ | En progreso |
| Zookeeper | ✅ | - | - | - | Descargado |
| Kafka | ⏳ | - | - | - | Descargando |
| Flink | ⏸️ | ⏸️ | ⏸️ | - | Pendiente |
| Spark | ⏸️ | ⏸️ | ⏸️ | - | Pendiente |
| HDFS | ⏸️ | ⏸️ | ⏸️ | ⏸️ | Pendiente |
| PostgreSQL | - | - | - | ⏸️ | Pendiente |
| Superset | - | - | - | ⏸️ | Pendiente |

#### Conectividad y Acceso

**SSH desde local**: ✅ Funcionando
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254  # Master
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.221.77.132  # Worker1
ssh -i ~/.ssh/bigd-key.pem ec2-user@3.219.215.11   # Worker2
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.88.249.180  # Storage
```

**Resolución de nombres internos**: ✅ Configurado
```bash
ping master-node    # → 172.31.72.49
ping worker1-node   # → 172.31.70.167
ping worker2-node   # → 172.31.15.51
ping storage-node   # → 172.31.31.171
```

#### Recursos del Sistema

| Instancia | vCPUs | RAM | Disco | Uso RAM | Disco Libre |
|-----------|-------|-----|-------|---------|-------------|
| Master | 2 | 1.9 GB | 30 GB | ~300 MB | ~28 GB |
| Worker1 | 2 | 4 GB | 30 GB | ~300 MB | ~28 GB |
| Worker2 | 2 | 4 GB | 30 GB | ~300 MB | ~28 GB |
| Storage | 2 | 8 GB | 30 GB | ~300 MB | ~28 GB |

---

## Próximos Pasos

### Inmediato (En las próximas 2 horas)

#### 1. Completar Instalación Automática ⏳

**Acción**: Esperar a que termine `./orchestrate-cluster.sh setup-all`

**Componentes pendientes de instalación**:

**Master Node**:
- ✅ Zookeeper 3.8.3
- ⏳ Kafka 3.6.0 (en progreso)
- ⏸️ Flink 1.18.0 JobManager
- ⏸️ Spark 3.5.0 Master
- ⏸️ Hadoop HDFS 3.3.6 NameNode

**Worker1 & Worker2**:
- ⏸️ Flink 1.18.0 TaskManager
- ⏸️ Spark 3.5.0 Worker
- ⏸️ Hadoop HDFS 3.3.6 DataNode

**Storage Node**:
- ⏸️ PostgreSQL 15
- ⏸️ Apache Superset 3.1.0
- ⏸️ Hadoop HDFS 3.3.6 DataNode

**Tiempo estimado**: 25-35 minutos adicionales

#### 2. Verificar Instalación Exitosa ✅

Cuando termine la instalación, verificar:

```bash
# Verificar versiones instaladas en Master
ssh ec2-user@44.210.18.254
java -version                                    # Java 11
ls /opt/bigdata/                                 # Directorios de software
ls /opt/bigdata/zookeeper-*                     # Zookeeper instalado
ls /opt/bigdata/kafka-*                         # Kafka instalado
ls /opt/bigdata/flink-*                         # Flink instalado
ls /opt/bigdata/spark-*                         # Spark instalado
ls /opt/bigdata/hadoop-*                        # HDFS instalado
```

```bash
# Verificar Workers
ssh ec2-user@44.221.77.132
ls /opt/bigdata/                                # Software instalado
```

```bash
# Verificar Storage
ssh ec2-user@98.88.249.180
psql --version                                  # PostgreSQL instalado
superset version                                # Superset instalado
```

#### 3. Iniciar Servicios del Cluster 🚀

**Opción A - Usando orchestrate-cluster.sh (Recomendado)**:
```bash
# Desde máquina local
cd bigdata-pipeline/infrastructure/scripts
./orchestrate-cluster.sh start-cluster
```

**Opción B - Manual**:

En **Master**:
```bash
ssh ec2-user@44.210.18.254

# 1. Iniciar Zookeeper
/opt/bigdata/zookeeper-3.8.3/bin/zkServer.sh start

# 2. Iniciar Kafka
/opt/bigdata/kafka-3.6.0/bin/kafka-server-start.sh -daemon \
  /opt/bigdata/kafka-3.6.0/config/server.properties

# 3. Iniciar HDFS NameNode
/opt/bigdata/hadoop-3.3.6/bin/hdfs --daemon start namenode

# 4. Iniciar Flink JobManager
/opt/bigdata/flink-1.18.0/bin/jobmanager.sh start

# 5. Iniciar Spark Master
/opt/bigdata/spark-3.5.0/sbin/start-master.sh
```

En **Worker1 & Worker2**:
```bash
# Para cada worker
ssh ec2-user@<WORKER_IP>

# 1. Iniciar HDFS DataNode
/opt/bigdata/hadoop-3.3.6/bin/hdfs --daemon start datanode

# 2. Iniciar Flink TaskManager
/opt/bigdata/flink-1.18.0/bin/taskmanager.sh start

# 3. Iniciar Spark Worker
/opt/bigdata/spark-3.5.0/sbin/start-worker.sh spark://master-node:7077
```

En **Storage**:
```bash
ssh ec2-user@98.88.249.180

# 1. Iniciar PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# 2. Iniciar HDFS DataNode
/opt/bigdata/hadoop-3.3.6/bin/hdfs --daemon start datanode

# 3. Iniciar Superset
superset run -h 0.0.0.0 -p 8088 --with-threads --reload --debugger &
```

#### 4. Verificar Estado de Servicios ✅

**Comando automatizado**:
```bash
./orchestrate-cluster.sh status
```

**Verificación manual**:

```bash
# En Master
ssh ec2-user@44.210.18.254
jps  # Debería mostrar: QuorumPeerMain, Kafka, NameNode, StandaloneSession, Master
```

**Verificar Web UIs** (desde navegador):
- HDFS NameNode: http://44.210.18.254:9870
- Spark Master: http://44.210.18.254:8080
- Flink Dashboard: http://44.210.18.254:8081
- Superset: http://98.88.249.180:8088

---

### Corto Plazo (Siguientes 4-8 horas)

#### 5. Crear Kafka Topics 📨

```bash
./orchestrate-cluster.sh create-topics
```

O manualmente:
```bash
ssh ec2-user@44.210.18.254
/opt/bigdata/kafka-3.6.0/bin/kafka-topics.sh --create \
  --bootstrap-server master-node:9092 \
  --topic taxi-trips \
  --partitions 3 \
  --replication-factor 1

# Verificar
/opt/bigdata/kafka-3.6.0/bin/kafka-topics.sh --list \
  --bootstrap-server master-node:9092
```

#### 6. Configurar PostgreSQL 🗄️

En Storage node:
```bash
ssh ec2-user@98.88.249.180

# Crear base de datos y usuario
sudo -u postgres psql <<EOF
CREATE DATABASE taxi_analytics;
CREATE USER bigdata WITH PASSWORD 'bigdata123';
GRANT ALL PRIVILEGES ON DATABASE taxi_analytics TO bigdata;
\q
EOF

# Crear tablas para streaming results
sudo -u postgres psql -d taxi_analytics <<EOF
CREATE TABLE zone_metrics (
    zone_id INTEGER,
    window_start TIMESTAMP,
    window_end TIMESTAMP,
    trip_count INTEGER,
    total_amount DECIMAL(10,2),
    avg_distance DECIMAL(10,2),
    avg_passengers DECIMAL(5,2),
    PRIMARY KEY (zone_id, window_start)
);

CREATE INDEX idx_zone_metrics_time ON zone_metrics(window_start, window_end);
CREATE INDEX idx_zone_metrics_zone ON zone_metrics(zone_id);
EOF
```

#### 7. Inicializar Superset 🎨

```bash
ssh ec2-user@98.88.249.180

# Crear usuario admin
superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@bigdata.com \
  --password admin123

# Inicializar base de datos
superset db upgrade

# Cargar ejemplos (opcional)
superset load_examples

# Inicializar roles
superset init
```

Acceder: http://98.88.249.180:8088
- Usuario: `admin`
- Password: `admin123`

#### 8. Descargar y Preparar Dataset 📊

**Dataset**: NYC Yellow Taxi Trip Data 2015

**Opción A - Descargar en Master**:
```bash
ssh ec2-user@44.210.18.254
mkdir -p /data/taxi-dataset

# Descargar 12 meses (2015)
cd /data/taxi-dataset
for month in {01..12}; do
  wget https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2015-${month}.parquet
done

# Verificar
ls -lh /data/taxi-dataset/
# Debería mostrar 12 archivos .parquet (~40-60 GB total)
```

**Opción B - Usar S3 (si ya está disponible)**:
```bash
# Configurar AWS CLI
aws configure

# Copiar desde S3
aws s3 sync s3://nyc-tlc/trip_data/ /data/taxi-dataset/ \
  --exclude "*" \
  --include "yellow_tripdata_2015-*.parquet"
```

---

### Mediano Plazo (Siguientes 1-2 días)

#### 9. Compilar y Desplegar Flink Jobs 🔄

**En Master**:
```bash
ssh ec2-user@44.210.18.254
cd ~/bigdata-pipeline/streaming/flink-jobs

# Compilar con Maven
mvn clean package

# Desplegar job
/opt/bigdata/flink-1.18.0/bin/flink run \
  target/taxi-streaming-jobs-1.0-SNAPSHOT.jar \
  --kafka-brokers master-node:9092 \
  --kafka-topic taxi-trips \
  --postgres-host storage-node \
  --postgres-db taxi_analytics \
  --postgres-user bigdata \
  --postgres-password bigdata123
```

**Verificar job en Flink UI**: http://44.210.18.254:8081

#### 10. Configurar Spark Batch Jobs ⚡

**Copiar jobs a cluster**:
```bash
# Desde máquina local
scp -i ~/.ssh/bigd-key.pem -r batch/spark-jobs/ \
  ec2-user@44.210.18.254:~/bigdata-pipeline/batch/
```

**Configurar cron para ejecución diaria**:
```bash
ssh ec2-user@44.210.18.254
crontab -e

# Agregar job diario a las 2 AM
0 2 * * * /opt/bigdata/spark-3.5.0/bin/spark-submit \
  --master spark://master-node:7077 \
  --deploy-mode cluster \
  ~/bigdata-pipeline/batch/spark-jobs/daily_summary.py \
  --date $(date -d "yesterday" +\%Y-\%m-\%d) \
  --input hdfs://master-node:9000/taxi/raw/ \
  --output hdfs://master-node:9000/taxi/processed/ \
  >> /var/log/bigdata/spark-daily.log 2>&1
```

#### 11. Implementar Data Producer 📡

**En Master**:
```bash
ssh ec2-user@44.210.18.254
cd ~/bigdata-pipeline/data-producer

# Instalar dependencias (ya instaladas en common-setup)
pip3 install -r requirements.txt

# Configurar producer
vim config.yaml
# Actualizar:
#   kafka_brokers: ["master-node:9092"]
#   dataset_path: "/data/taxi-dataset/"
#   replay_speed: 100  # 100x más rápido que tiempo real

# Ejecutar producer en background
nohup python3 src/producer.py --config config.yaml \
  > /var/log/bigdata/producer.log 2>&1 &

# Verificar logs
tail -f /var/log/bigdata/producer.log
```

#### 12. Configurar Dashboards en Superset 📈

1. Acceder a Superset: http://98.88.249.180:8088
2. Crear Database Connection a PostgreSQL
3. Crear Datasets desde tablas
4. Crear Charts:
   - Line Chart: Viajes por minuto
   - Bar Chart: Top 10 zonas
   - Pie Chart: Métodos de pago
   - Big Number: Total ingresos en tiempo real
5. Crear Dashboard combinando charts

---

### Largo Plazo (Próxima semana)

#### 13. Optimización y Monitoreo 📊

- Configurar alertas en Superset
- Implementar logging centralizado
- Configurar backups de PostgreSQL
- Optimizar configuraciones de Spark/Flink basado en uso real
- Configurar auto-scaling (si se requiere)

#### 14. Análisis Avanzados 🔬

- Implementar ML models con Spark MLlib
- Crear análisis de series temporales
- Implementar detección de anomalías
- Generar reportes automatizados

#### 15. Documentación Final 📝

- Screenshots de dashboards
- Métricas de rendimiento reales
- Lecciones aprendidas
- Guía de mantenimiento

---

## Configuración Final del Cluster

### Arquitectura de Servicios

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS VPC (us-east-1)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Master (172.31.72.49)       Worker1 (172.31.70.167)           │
│  ┌──────────────────┐        ┌──────────────────┐             │
│  │ Zookeeper :2181  │        │ Flink TM  :6121  │             │
│  │ Kafka     :9092  │        │ Spark W   :7077  │             │
│  │ Flink JM  :8081  │        │ HDFS DN   :9866  │             │
│  │ Spark M   :8080  │        └──────────────────┘             │
│  │ HDFS NN   :9870  │                                          │
│  │ Data Prod :9999  │        Worker2 (172.31.15.51)           │
│  └──────────────────┘        ┌──────────────────┐             │
│                               │ Flink TM  :6121  │             │
│  Storage (172.31.31.171)     │ Spark W   :7077  │             │
│  ┌──────────────────┐        │ HDFS DN   :9866  │             │
│  │ PostgreSQL :5432 │        └──────────────────┘             │
│  │ Superset   :8088 │                                          │
│  │ HDFS DN    :9866 │                                          │
│  └──────────────────┘                                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### URLs de Acceso

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| HDFS NameNode | http://44.210.18.254:9870 | - |
| Spark Master | http://44.210.18.254:8080 | - |
| Flink Dashboard | http://44.210.18.254:8081 | - |
| Superset | http://98.88.249.180:8088 | admin/admin123 |
| PostgreSQL | storage-node:5432 | bigdata/bigdata123 |

### Comandos Útiles

#### Iniciar/Detener Cluster Completo

```bash
# Desde máquina local
cd bigdata-pipeline/infrastructure/scripts

# Iniciar todo
./orchestrate-cluster.sh start-cluster

# Detener todo
./orchestrate-cluster.sh stop-cluster

# Ver estado
./orchestrate-cluster.sh status
```

#### Monitorear Logs

```bash
# Master - Kafka
ssh ec2-user@44.210.18.254
tail -f /opt/bigdata/kafka-3.6.0/logs/server.log

# Master - Flink
tail -f /opt/bigdata/flink-1.18.0/log/flink-*-standalonesession-*.log

# Workers - TaskManager
ssh ec2-user@44.221.77.132
tail -f /opt/bigdata/flink-1.18.0/log/flink-*-taskexecutor-*.log

# Storage - PostgreSQL
ssh ec2-user@98.88.249.180
sudo tail -f /var/lib/pgsql/15/data/log/postgresql-*.log
```

#### Verificar Procesos Java

```bash
# En cualquier nodo
jps -l
# Muestra todos los procesos Java con nombres completos
```

#### Reiniciar Servicios Individuales

```bash
# Ejemplo: Reiniciar Kafka en Master
ssh ec2-user@44.210.18.254
/opt/bigdata/kafka-3.6.0/bin/kafka-server-stop.sh
sleep 5
/opt/bigdata/kafka-3.6.0/bin/kafka-server-start.sh -daemon \
  /opt/bigdata/kafka-3.6.0/config/server.properties
```

---

## Costos y Recursos

### Costos Estimados (AWS Free Tier)

| Recurso | Costo/hora | Costo/día (24h) | Costo/mes |
|---------|------------|-----------------|-----------|
| t3.small (Master) | $0.0208 | $0.50 | $15.00 |
| c7i-flex.large (Worker1) | $0.0880 | $2.11 | $63.36 |
| c7i-flex.large (Worker2) | $0.0880 | $2.11 | $63.36 |
| m7i-flex.large (Storage) | $0.0940 | $2.26 | $67.68 |
| EBS gp3 (120 GB) | $0.0100 | $0.24 | $7.20 |
| **TOTAL** | **$0.3008** | **$7.22** | **$216.60** |

**Estrategia de ahorro**:
- Apagar instancias fuera de horario de desarrollo
- Usar instance scheduler
- Considerar Spot Instances para Workers (70% descuento)
- Reducir volúmenes EBS si no se necesita todo el espacio

### Uso de Recursos Esperado

| Métrica | Streaming (idle) | Streaming (activo) | Batch Processing |
|---------|------------------|-------------------|------------------|
| CPU Master | 10-20% | 40-60% | 30-50% |
| CPU Workers | 5-10% | 70-90% | 80-95% |
| RAM Master | 30-40% | 50-70% | 40-60% |
| RAM Workers | 20-30% | 60-80% | 70-90% |
| Network | 1-5 Mbps | 10-50 Mbps | 20-100 Mbps |
| Disk I/O | Bajo | Medio | Alto |

---

## Contacto y Soporte

**Equipo del Proyecto**:
- Fabián
- Fernando
- Jorge

**Repositorio**: https://github.com/fernandoramirez1337/bigdata-pipeline

**Branch actual**: `claude/aws-ec2-distributed-plan-018mA2bSY4uvxcLBuHq1CkDS`

**Documentación adicional**:
- [README.md](../README.md) - Visión general del proyecto
- [PLAN_ARQUITECTURA.md](../PLAN_ARQUITECTURA.md) - Diseño detallado
- [END_TO_END_EXAMPLE.md](../END_TO_END_EXAMPLE.md) - Tutorial completo
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Guía de despliegue

---

**Última actualización**: 20 de Noviembre 2025, 15:05 UTC
**Estado del cluster**: Instalación en progreso (Kafka downloading ~7%)
**Próxima acción**: Esperar finalización de `setup-all` (~25-35 minutos)
