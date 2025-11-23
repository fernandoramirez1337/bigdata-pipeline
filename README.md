# NYC Taxi Big Data Pipeline

Pipeline completo de Big Data para análisis de viajes de taxi de Nueva York con procesamiento en tiempo real (streaming) y por lotes (batch) distribuido en AWS EC2.

## 🚀 Quick Start - Starting the Cluster

### Recommended Method: Interactive Startup

**Use `quick-start.sh` for the best experience:**

```bash
./quick-start.sh
```

This interactive script will:
- ✅ Verify SSH key
- ✅ Configure cluster IPs (saves to `.cluster-ips` for other scripts)
- ✅ Test connectivity
- ✅ Verify /etc/hosts
- ✅ Start all services in correct order
- ✅ Provide next steps

**Prerequisites:**
- EC2 instances are running
- SSH key `bigd-key.pem` is available (or path to your key)
- Know your current instance IPs

**Time: ~3-5 minutes** to start all services

### Alternative Methods:

```bash
# Direct startup (uses saved IPs from .cluster-ips)
./infrastructure/scripts/start-cluster.sh

# Step-by-step manual process
# See: docs/guides/START_CLUSTER_CHECKLIST.md
```

**Important:** Always use `quick-start.sh` first to configure IPs. Other scripts will automatically use the saved configuration.

---

## Descripción del Proyecto

Este proyecto implementa un pipeline de Big Data end-to-end que procesa datos históricos de taxis de NYC simulando un entorno de producción en tiempo real. Incluye:

- **Ingesta de datos**: Data producer con replay acelerado
- **Streaming processing**: Apache Flink para métricas en tiempo real
- **Batch processing**: Apache Spark para análisis históricos
- **Storage**: HDFS, PostgreSQL y S3
- **Visualización**: Apache Superset con dashboards interactivos

## Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                    AWS EC2 Distributed Cluster                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  EC2-1 (Master)          EC2-2 (Worker1)         EC2-3 (Worker2)│
│  ├─ Kafka               ├─ Flink TaskMgr        ├─ Flink TaskMgr│
│  ├─ Zookeeper           ├─ Spark Worker         ├─ Spark Worker │
│  ├─ Flink JobMgr        ├─ HDFS DataNode        ├─ HDFS DataNode│
│  ├─ Spark Master        └─ Processing           └─ Processing   │
│  ├─ HDFS NameNode                                               │
│  └─ Data Producer       EC2-4 (Storage)                         │
│                         ├─ PostgreSQL                           │
│                         ├─ Apache Superset                      │
│                         ├─ HDFS DataNode                        │
│                         └─ S3 Connector                         │
└─────────────────────────────────────────────────────────────────┘
```

## Características Principales

### 🚀 Deployment Automatizado
- **create-cluster.sh**: Crea 4 EC2 con Security Group en 5 minutos
- **orchestrate-cluster.sh**: Instala todo el software con un comando
- Configuración automática de firewall y red
- Genera archivo con IPs y comandos SSH listos

### 📊 Pipeline Completo
- **Streaming**: Procesamiento en tiempo real con Flink (1-minute windows)
- **Batch**: Análisis históricos diarios con Spark
- **Storage**: HDFS distribuido + PostgreSQL + S3
- **Visualization**: Dashboards interactivos con Superset

### 🔧 Tecnologías

- **Streaming**: Apache Kafka 3.6.0, Apache Flink 1.18.0
- **Batch**: Apache Spark 3.5.0
- **Storage**: HDFS 3.3.6, PostgreSQL 15, Amazon S3
- **Visualization**: Apache Superset 3.1.0
- **Infrastructure**: AWS EC2 (Amazon Linux 2023)

## Dataset

- **Fuente**: [NYC Yellow Taxi Trip Data (Kaggle)](https://www.kaggle.com/datasets/elemento/nyc-yellow-taxi-trip-data)
- **Periodo**: 12 meses (2015)
- **Tamaño**: ~40-60 GB
- **Registros**: ~165 millones de viajes

## Estructura del Proyecto

```
bigdata-pipeline/
├── docs/guides/PLAN_ARQUITECTURA.md          # Plan detallado de arquitectura
├── docs/
│   ├── DEPLOYMENT_GUIDE.md       # Guía de despliegue paso a paso
│   └── troubleshooting.md
├── infrastructure/
│   ├── scripts/
│   │   ├── common-setup.sh       # Setup común para todas las EC2
│   │   ├── setup-master.sh       # Setup Master node
│   │   ├── setup-worker.sh       # Setup Worker nodes
│   │   ├── setup-storage.sh      # Setup Storage node
│   │   └── orchestrate-cluster.sh # Orquestación del cluster
│   └── configs/                  # Configuraciones de servicios
├── data-producer/
│   ├── src/
│   │   ├── producer.py           # Data producer principal
│   │   ├── kafka_client.py       # Cliente Kafka
│   │   └── dataset_loader.py     # Cargador de dataset
│   ├── config.yaml               # Configuración del producer
│   └── requirements.txt
├── streaming/
│   ├── flink-jobs/
│   │   ├── src/main/java/com/bigdata/taxi/
│   │   │   ├── ZoneAggregationJob.java
│   │   │   ├── model/TaxiTrip.java
│   │   │   └── model/ZoneMetrics.java
│   │   └── pom.xml
│   └── build.sh
├── batch/
│   ├── spark-jobs/
│   │   ├── daily_summary.py      # Job batch diario
│   │   ├── hourly_zones.py       # Análisis por hora y zona
│   │   └── route_analysis.py     # Análisis de rutas
│   └── schedules/
└── visualization/
    ├── sql/
    │   └── sample-queries.sql    # Queries para Superset
    └── superset/
        └── dashboards/
```

## Quick Start

### Opción A: Automatizada (Recomendada) ⭐

```bash
# 1. Clonar repositorio
git clone https://github.com/fernandoramirez1337/bigdata-pipeline.git
cd bigdata-pipeline/infrastructure/scripts

# 2. Crear 4 EC2 instances automáticamente
export KEY_NAME="bigd-key"
export MY_IP="$(curl -s ifconfig.me)/32"
./create-cluster.sh

# 3. Configurar /etc/hosts en todas las instancias
# (Copiar comandos de cluster-info.txt generado)

# 4. Actualizar IPs en orchestrate-cluster.sh
vim orchestrate-cluster.sh
# Actualizar MASTER_IP, WORKER1_IP, WORKER2_IP, STORAGE_IP

# 5. Instalar software (30-45 min)
./orchestrate-cluster.sh setup-all

# 6. Iniciar cluster
./orchestrate-cluster.sh start-cluster
```

**Ver tutorial completo**: [END_TO_END_EXAMPLE.md](docs/guides/END_TO_END_EXAMPLE.md)

### Opción B: Manual

Ver detalles en [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)

### 3. Desplegar Pipeline

```bash
# Crear Kafka topic
./infrastructure/scripts/orchestrate-cluster.sh create-topics

# Iniciar data producer
ssh ec2-user@<MASTER_IP>
cd bigdata-pipeline/data-producer
python3 src/producer.py --config config.yaml

# Desplegar Flink job
cd ../streaming
bash build.sh
flink run flink-jobs/target/taxi-streaming-jobs-1.0-SNAPSHOT.jar

# Configurar Spark batch jobs
crontab -e
# Agregar job diario a las 2 AM
```

### 4. Acceder a Dashboards

- **HDFS**: http://\<MASTER_IP\>:9870
- **Spark**: http://\<MASTER_IP\>:8080
- **Flink**: http://\<MASTER_IP\>:8081
- **Superset**: http://\<STORAGE_IP\>:8088 (admin/admin123)

## Análisis Implementados

### Dashboards en Tiempo Real (Streaming)

1. Viajes por zona/minuto
2. Ingresos totales en tiempo real
3. Top 10 zonas más activas
4. Distribución de métodos de pago
5. Métricas promedio (tarifa, distancia, pasajeros)

### Reportes Batch

1. Evolución de viajes diarios
2. Análisis por hora del día
3. Patrones por día de semana
4. Rutas más frecuentes
5. Correlación distancia-tarifa
6. Zonas con mayor ingreso

## Métricas de Rendimiento

- **Throughput**: ~1000 eventos/segundo
- **Latencia de streaming**: <5 segundos
- **Procesamiento batch**: ~10 minutos para 1 día de datos
- **Almacenamiento HDFS**: 3x replicación, ~150 GB

## Costos Estimados

### AWS EC2 (us-east-1)
- **Por hora**: ~$0.50
- **Con $50**: ~100 horas de operación
- **Estrategia**: Apagar instancias cuando no se usen

### Storage
- **EBS (550 GB)**: ~$26/mes
- **S3 (60 GB)**: ~$1.40/mes

## Integrantes

- Fabián
- Fernando
- Jorge

## Documentación

### Guías Principales

- 🚀 **[END_TO_END_EXAMPLE.md](docs/guides/END_TO_END_EXAMPLE.md)** - Tutorial completo del zero al dashboard (3-4 horas)
- 📋 **[PLAN_ARQUITECTURA.md](docs/guides/PLAN_ARQUITECTURA.md)** - Diseño completo del sistema (20+ páginas)
- 📖 **[DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)** - Instalación detallada paso a paso
- ⚡ **[QUICK_START_4EC2.md](docs/QUICK_START_4EC2.md)** - Checklist rápido de deployment

### Documentos de Implementación (NUEVO)

- 📝 **[IMPLEMENTATION_LOG.md](docs/IMPLEMENTATION_LOG.md)** - Log detallado de implementación con problemas y soluciones
- ✅ **[CHECKLIST.md](docs/CHECKLIST.md)** - Checklist completo de todas las fases del proyecto

### Recursos Técnicos

- **[Scripts README](infrastructure/scripts/README.md)** - Documentación de scripts de infraestructura
- **[Queries SQL](visualization/sql/sample-queries.sql)** - 18+ queries para dashboards de Superset

## Troubleshooting

Ver [Deployment Guide - Troubleshooting](docs/DEPLOYMENT_GUIDE.md#troubleshooting)

## Licencia

MIT License - Proyecto académico

## Referencias

- [NYC TLC Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page)
- [Apache Flink Documentation](https://flink.apache.org/)
- [Apache Spark Documentation](https://spark.apache.org/)
- [Apache Kafka Documentation](https://kafka.apache.org/)
