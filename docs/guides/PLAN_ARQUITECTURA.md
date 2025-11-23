# Plan de Arquitectura Big Data - NYC Taxi Pipeline
## AWS Academy Learner Lab - us-east-1

---

## 📋 Resumen Ejecutivo

**Objetivo**: Implementar pipeline completo de Big Data para análisis de viajes de taxi NYC con procesamiento batch y streaming distribuido en AWS EC2.

**Dataset**: NYC Yellow Taxi Trip Data (12 meses, ~40-60 GB)
**Región**: us-east-1 (Virginia)
**Presupuesto**: $50 USD por cuenta
**Visualización**: Apache Superset (open source)

---

## 🏗️ Arquitectura Propuesta

### Opción A: 4 EC2 (RECOMENDADA para alta disponibilidad)

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS us-east-1                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ EC2-1: MASTER/COORDINATOR (t3.large - 2 vCPU, 8GB RAM)  │  │
│  ├──────────────────────────────────────────────────────────┤  │
│  │ • Kafka Broker + Zookeeper                               │  │
│  │ • Flink JobManager                                       │  │
│  │ • Spark Master                                           │  │
│  │ • HDFS NameNode                                          │  │
│  │ • Data Producer (Replay Engine)                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              ├────────────────┬─────────────┐   │
│                              ▼                ▼             ▼   │
│  ┌────────────────────┐ ┌────────────────────┐ ┌─────────────┐ │
│  │ EC2-2: WORKER-1    │ │ EC2-3: WORKER-2    │ │ EC2-4:      │ │
│  │ (t3.xlarge)        │ │ (t3.xlarge)        │ │ STORAGE     │ │
│  │ 4 vCPU, 16GB       │ │ 4 vCPU, 16GB       │ │ (t3.large)  │ │
│  ├────────────────────┤ ├────────────────────┤ ├─────────────┤ │
│  │ • Flink TaskMgr    │ │ • Flink TaskMgr    │ │ • HDFS DN   │ │
│  │ • Spark Worker     │ │ • Spark Worker     │ │ • PostgreSQL│ │
│  │ • HDFS DataNode    │ │ • HDFS DataNode    │ │ • Superset  │ │
│  │ • Kafka Consumer   │ │ • Kafka Consumer   │ │ • S3 Sync   │ │
│  └────────────────────┘ └────────────────────┘ └─────────────┘ │
│                              │                                   │
│                              ▼                                   │
│                     ┌─────────────────┐                         │
│                     │   Amazon S3     │                         │
│                     │ (Batch Results) │                         │
│                     └─────────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
```

**Costo estimado**: ~$2.50-3.00/hora (toda la infraestructura)

### Opción B: 3 EC2 (Optimizada para presupuesto)

```
┌──────────────────────┐ ┌──────────────────────┐ ┌──────────────────────┐
│ EC2-1: MASTER        │ │ EC2-2: WORKER        │ │ EC2-3: STORAGE       │
│ (t3.xlarge)          │ │ (t3.xlarge)          │ │ (t3.large)           │
├──────────────────────┤ ├──────────────────────┤ ├──────────────────────┤
│ • Kafka + Zookeeper  │ │ • Flink TaskMgr      │ │ • HDFS DataNode      │
│ • Flink JobManager   │ │ • Spark Worker       │ │ • PostgreSQL         │
│ • Spark Master       │ │ • HDFS DataNode      │ │ • Apache Superset    │
│ • HDFS NameNode      │ │ • Procesamiento      │ │ • S3 Connector       │
│ • Data Producer      │ │ • Batch + Stream     │ │ • Visualización      │
└──────────────────────┘ └──────────────────────┘ └──────────────────────┘
```

**Costo estimado**: ~$1.80-2.20/hora

---

## 🔄 Flujo de Datos Completo

### Pipeline de Streaming (Tiempo Real)

```
1. Data Producer (EC2-1)
   ↓
   Reproduce datos históricos con timestamps acelerados
   ↓
2. Kafka Topic: "taxi-trips-stream" (EC2-1)
   ↓
   Particiones: 3 (para distribución)
   ↓
3. Apache Flink (EC2-2, EC2-3)
   ↓
   • Window Operations (1 minuto)
   • Agregaciones en tiempo real:
     - Viajes por zona/minuto
     - Ingresos totales/minuto
     - Distancia promedio
     - Tipos de pago
   ↓
4. PostgreSQL (EC2-4/Storage)
   ↓
   Tablas actualizadas en tiempo real
   ↓
5. Apache Superset - Dashboard Tiempo Real
```

### Pipeline Batch (Procesamiento Histórico)

```
1. Kafka Consumer → HDFS Writer (EC2-2, EC2-3)
   ↓
   Escritura continua a HDFS cada hora
   ↓
2. HDFS Storage (Distribuido EC2-2, EC2-3, EC2-4)
   ↓
   Particionado por fecha: /data/taxi/year=2015/month=01/day=01/
   ↓
3. Apache Spark - Batch Jobs (Diario)
   ↓
   • Evolución de viajes diarios
   • Promedio de tarifa por zona
   • Análisis horario (horas pico)
   • Patrones por día de semana
   • Correlación distancia-tarifa
   ↓
4. Resultados → S3 + PostgreSQL
   ↓
   • S3: Archivos Parquet particionados
   • PostgreSQL: Tablas agregadas
   ↓
5. Apache Superset - Dashboards Batch
```

---

## 📊 Análisis y Métricas

### Dashboards en Tiempo Real (Stream Processing)

1. **Actividad en Tiempo Real**
   - Viajes por zona/minuto (mapa de calor)
   - Top 10 zonas más activas
   - Viajes activos en este momento

2. **Ingresos en Tiempo Real**
   - Ingresos totales/minuto
   - Tarifa promedio actual
   - Propinas promedio

3. **Comportamiento de Pasajeros**
   - Distribución de número de pasajeros
   - Métodos de pago más usados (últimos 5 min)
   - Distancia promedio de viajes activos

### Reportes Batch (Procesamiento Diario)

1. **Análisis Temporal**
   - Evolución de viajes por día/semana/mes
   - Horas pico de demanda
   - Tendencias por día de semana
   - Estacionalidad

2. **Análisis Económico**
   - Promedio de ticket por viaje
   - Ingresos totales por zona
   - Correlación distancia-tarifa
   - Análisis de propinas (% por tipo de pago)

3. **Análisis Geográfico**
   - Rutas más frecuentes (pickup → dropoff)
   - Zonas con mayor ingreso promedio
   - Distancia promedio por zona
   - Mapa de demanda por hora del día

4. **Análisis de Eficiencia**
   - Duración promedio de viajes
   - Velocidad promedio por zona/hora
   - Ocupación promedio (pasajeros)

---

## 💾 Estrategia de Almacenamiento

### Almacenamiento por Capa

| Capa | Tecnología | Ubicación | Propósito | Retención |
|------|------------|-----------|-----------|-----------|
| **Raw Data** | HDFS | EC2-2,3,4 | Datos originales | 7 días |
| **Streaming State** | RocksDB (Flink) | EC2-2,3 | Estado de ventanas | Temporal |
| **Real-time Metrics** | PostgreSQL | EC2-4 | Dashboards RT | 24 horas |
| **Batch Results** | S3 Parquet | S3 Bucket | Análisis histórico | Permanente |
| **Aggregated Data** | PostgreSQL | EC2-4 | Superset queries | Permanente |

### Esquema de Particionamiento

**HDFS:**
```
/data/taxi/
├── raw/
│   ├── year=2015/
│   │   ├── month=01/
│   │   │   ├── day=01/
│   │   │   │   └── part-00000.parquet
```

**S3:**
```
s3://bigdata-taxi-pipeline/
├── batch-results/
│   ├── daily-summary/year=2015/month=01/
│   ├── hourly-zones/year=2015/month=01/
│   └── route-analysis/year=2015/month=01/
```

**PostgreSQL:**
```sql
-- Streaming metrics
CREATE TABLE real_time_zones (
    zone_id INT,
    window_start TIMESTAMP,
    trip_count INT,
    total_revenue DECIMAL,
    avg_distance DECIMAL,
    PRIMARY KEY (zone_id, window_start)
);

-- Batch aggregations
CREATE TABLE daily_summary (
    date DATE PRIMARY KEY,
    total_trips INT,
    total_revenue DECIMAL,
    avg_fare DECIMAL,
    avg_distance DECIMAL
);
```

---

## 🚀 Especificaciones Técnicas de EC2

### EC2-1: Master/Coordinator

**Instancia**: t3.large (2 vCPU, 8 GB RAM)
**Almacenamiento**: 100 GB gp3
**Componentes**:

```yaml
Kafka:
  version: 3.6.0
  config:
    num.partitions: 3
    replication.factor: 1
    log.retention.hours: 24
    log.segment.bytes: 1GB

Zookeeper:
  version: 3.8.3
  data.dir: /data/zookeeper

Flink JobManager:
  version: 1.18.0
  jobmanager.memory: 2GB

Spark Master:
  version: 3.5.0
  master.memory: 2GB

HDFS NameNode:
  version: 3.3.6
  namenode.memory: 2GB
```

### EC2-2 & EC2-3: Workers (Idénticos)

**Instancia**: t3.xlarge (4 vCPU, 16 GB RAM)
**Almacenamiento**: 200 GB gp3 cada uno
**Componentes**:

```yaml
Flink TaskManager:
  version: 1.18.0
  taskmanager.memory: 6GB
  taskmanager.numberOfTaskSlots: 4

Spark Worker:
  version: 3.5.0
  worker.memory: 6GB
  worker.cores: 4

HDFS DataNode:
  version: 3.3.6
  datanode.memory: 2GB
  storage: 150GB
```

### EC2-4: Storage/Visualization

**Instancia**: t3.large (2 vCPU, 8 GB RAM)
**Almacenamiento**: 150 GB gp3
**Componentes**:

```yaml
PostgreSQL:
  version: 15
  shared_buffers: 2GB
  max_connections: 100

Apache Superset:
  version: 3.1.0
  workers: 2

HDFS DataNode:
  version: 3.3.6
  storage: 100GB
```

---

## 💰 Estimación de Costos (AWS Academy)

### Opción A: 4 EC2

| Recurso | Tipo | Costo/hora | Horas/día | Costo/día | Costo/30d |
|---------|------|------------|-----------|-----------|-----------|
| EC2-1 Master | t3.large | $0.0832 | 24 | $2.00 | $60.00 |
| EC2-2 Worker | t3.xlarge | $0.1664 | 24 | $4.00 | $120.00 |
| EC2-3 Worker | t3.xlarge | $0.1664 | 24 | $4.00 | $120.00 |
| EC2-4 Storage | t3.large | $0.0832 | 24 | $2.00 | $60.00 |
| EBS (550 GB) | gp3 | - | - | $0.88 | $26.40 |
| S3 (60 GB) | Standard | - | - | $0.05 | $1.40 |
| Transfer OUT | 10 GB | - | - | $0.30 | $9.00 |
| **TOTAL** | | **$0.50** | - | **$13.23** | **$396.80** |

**⚠️ Nota**: Con $50 puedes correr el cluster completo por ~3.5 horas (suficiente para demos y pruebas)

### Opción B: 3 EC2 (Presupuesto Optimizado)

| Recurso | Tipo | Costo/hora | Costo/día | Costo/30d |
|---------|------|------------|-----------|-----------|
| EC2-1 Master | t3.xlarge | $0.1664 | $4.00 | $120.00 |
| EC2-2 Worker | t3.xlarge | $0.1664 | $4.00 | $120.00 |
| EC2-3 Storage | t3.large | $0.0832 | $2.00 | $60.00 |
| EBS + S3 | - | - | $0.93 | $27.80 |
| **TOTAL** | | **$0.42** | **$10.93** | **$327.80** |

**Con $50**: ~5 horas de operación

### Estrategia de Optimización de Costos

1. **Uso Intermitente**:
   - Levantar cluster solo cuando se necesite
   - Apagar fuera de horario de desarrollo
   - Usar múltiples cuentas de $50

2. **Schedule Sugerido**:
   ```
   Cuenta 1 ($50): Configuración + Testing (5 horas)
   Cuenta 2 ($50): Carga de datos + Pipeline batch (5 horas)
   Cuenta 3 ($50): Streaming + Dashboards + Demos (5 horas)
   Total: ~15 horas de operación
   ```

3. **Optimizaciones**:
   - Descargar dataset a una cuenta S3, acceder desde todas
   - Snapshots de EBS con configuración completa
   - Scripts de start/stop automatizados

---

## 🎯 Data Producer - Replay Engine

### Características

```python
Replay Accelerator:
  - Lee datos históricos ordenados por timestamp
  - Acelera reproducción: 1000x (1 día = 86 segundos)
  - Mantiene distribución temporal original
  - Produce a Kafka con rate limiting configurable

Configuración:
  - Archivo fuente: s3://datasets/nyc-taxi/2015-*.parquet
  - Rate: 1000 registros/segundo
  - Modo: continuo (loop) o único (one-shot)
  - Jitter: ±10% para simular variabilidad real
```

### Campos Dataset NYC Taxi

```python
Schema:
  - VendorID: int
  - tpep_pickup_datetime: timestamp
  - tpep_dropoff_datetime: timestamp
  - passenger_count: int
  - trip_distance: float
  - pickup_longitude: float
  - pickup_latitude: float
  - RatecodeID: int
  - store_and_fwd_flag: string
  - dropoff_longitude: float
  - dropoff_latitude: float
  - payment_type: int (1=Credit, 2=Cash, 3=No charge, 4=Dispute)
  - fare_amount: float
  - extra: float
  - mta_tax: float
  - tip_amount: float
  - tolls_amount: float
  - total_amount: float
```

---

## 📈 Jobs de Procesamiento

### Flink Streaming Job

**Ventanas de Agregación**:

```java
// 1. Viajes por zona cada minuto
TripStream
  .keyBy(trip -> getPickupZone(trip.pickup_lat, trip.pickup_lon))
  .window(TumblingProcessingTimeWindows.of(Time.minutes(1)))
  .aggregate(new TripCountAggregator())
  .addSink(new PostgreSQLSink("real_time_zones"));

// 2. Ingresos en tiempo real
TripStream
  .windowAll(SlidingProcessingTimeWindows.of(Time.minutes(5), Time.seconds(30)))
  .aggregate(new RevenueAggregator())
  .addSink(new PostgreSQLSink("real_time_revenue"));

// 3. Top zonas activas
TripStream
  .keyBy(trip -> getPickupZone(...))
  .window(TumblingProcessingTimeWindows.of(Time.minutes(5)))
  .aggregate(new ZoneActivityAggregator())
  .windowAll(TumblingProcessingTimeWindows.of(Time.minutes(5)))
  .process(new TopNZones(10))
  .addSink(new PostgreSQLSink("top_zones"));
```

### Spark Batch Jobs

**Job 1: Daily Summary**
```scala
// Ejecuta diariamente a las 2 AM
spark.read.parquet("hdfs:///data/taxi/year=*/month=*/day=*/")
  .filter($"tpep_pickup_datetime".cast("date") === current_date - 1)
  .groupBy($"tpep_pickup_datetime".cast("date").as("date"))
  .agg(
    count("*").as("total_trips"),
    sum("total_amount").as("total_revenue"),
    avg("fare_amount").as("avg_fare"),
    avg("trip_distance").as("avg_distance")
  )
  .write.mode("append")
  .parquet("s3://bucket/batch-results/daily-summary/")
```

**Job 2: Hourly Zone Analysis**
```scala
// Análisis por zona y hora
spark.read.parquet("hdfs:///data/taxi/")
  .withColumn("hour", hour($"tpep_pickup_datetime"))
  .withColumn("zone", getZoneUDF($"pickup_latitude", $"pickup_longitude"))
  .groupBy("zone", "hour")
  .agg(
    count("*").as("trip_count"),
    avg("total_amount").as("avg_revenue"),
    avg("trip_distance").as("avg_distance")
  )
  .write.partitionBy("zone")
  .parquet("s3://bucket/batch-results/hourly-zones/")
```

**Job 3: Route Analysis**
```scala
// Rutas más frecuentes
spark.read.parquet("hdfs:///data/taxi/")
  .withColumn("pickup_zone", getZoneUDF($"pickup_latitude", $"pickup_longitude"))
  .withColumn("dropoff_zone", getZoneUDF($"dropoff_latitude", $"dropoff_longitude"))
  .groupBy("pickup_zone", "dropoff_zone")
  .agg(
    count("*").as("route_count"),
    avg("total_amount").as("avg_fare"),
    avg("trip_distance").as("avg_distance"),
    avg("duration_minutes").as("avg_duration")
  )
  .orderBy(desc("route_count"))
  .limit(1000)
  .write.parquet("s3://bucket/batch-results/route-analysis/")
```

---

## 🎨 Apache Superset - Dashboards

### Dashboard 1: Tiempo Real (Stream)

**Gráficos**:

1. **Big Number - Viajes Activos**
   - Query: `SELECT SUM(trip_count) FROM real_time_zones WHERE window_start > NOW() - INTERVAL '1 minute'`

2. **Line Chart - Viajes/Minuto (últimos 30 min)**
   - X: window_start
   - Y: trip_count
   - Refresh: 10 segundos

3. **Map - Zonas Activas**
   - Heatmap de viajes por zona
   - Datos últimos 5 minutos

4. **Bar Chart - Top 10 Zonas**
   - Zonas con más viajes en tiempo real

5. **Pie Chart - Métodos de Pago**
   - Distribución últimos 5 minutos

### Dashboard 2: Análisis Histórico (Batch)

**Gráficos**:

1. **Line Chart - Evolución Diaria**
   - Serie temporal de viajes por día
   - Filtros por rango de fechas

2. **Heatmap - Demanda por Hora/Día**
   - Rows: Día de semana
   - Cols: Hora del día
   - Color: Número de viajes

3. **Sankey Diagram - Rutas Principales**
   - Origen → Destino
   - Grosor: Frecuencia

4. **Box Plot - Distribución de Tarifas**
   - Por zona / hora del día

5. **Scatter Plot - Distancia vs Tarifa**
   - Correlación y outliers

---

## 📦 Estructura del Proyecto

```
bigdata-pipeline/
├── README.md
├── PLAN_ARQUITECTURA.md (este archivo)
├── docs/
│   ├── deployment-guide.md
│   ├── troubleshooting.md
│   └── cost-optimization.md
├── infrastructure/
│   ├── terraform/                    # IaC (opcional)
│   │   ├── main.tf
│   │   ├── ec2.tf
│   │   └── security-groups.tf
│   ├── scripts/
│   │   ├── setup-master.sh          # Setup EC2-1
│   │   ├── setup-worker.sh          # Setup EC2-2,3
│   │   ├── setup-storage.sh         # Setup EC2-4
│   │   ├── start-cluster.sh
│   │   └── stop-cluster.sh
│   └── configs/
│       ├── kafka/
│       │   └── server.properties
│       ├── flink/
│       │   ├── flink-conf.yaml
│       │   └── masters
│       ├── spark/
│       │   └── spark-defaults.conf
│       └── hdfs/
│           ├── core-site.xml
│           └── hdfs-site.xml
├── data-producer/
│   ├── src/
│   │   ├── producer.py              # Main replay engine
│   │   ├── kafka_client.py
│   │   └── dataset_loader.py
│   ├── requirements.txt
│   └── config.yaml
├── streaming/
│   ├── flink-jobs/
│   │   ├── pom.xml
│   │   └── src/main/java/
│   │       ├── ZoneAggregationJob.java
│   │       ├── RevenueAggregationJob.java
│   │       └── TopZonesJob.java
│   └── build.sh
├── batch/
│   ├── spark-jobs/
│   │   ├── daily_summary.py
│   │   ├── hourly_zones.py
│   │   ├── route_analysis.py
│   │   └── utils/
│   │       └── zone_mapping.py
│   └── schedules/
│       └── cron-jobs.txt
├── visualization/
│   ├── superset/
│   │   ├── dashboards/
│   │   │   ├── realtime-dashboard.json
│   │   │   └── batch-dashboard.json
│   │   └── setup.sh
│   └── sql/
│       ├── create-tables.sql
│       └── sample-queries.sql
├── tests/
│   ├── integration/
│   └── performance/
└── monitoring/
    ├── prometheus/
    │   └── prometheus.yml
    └── grafana/
        └── dashboards/
```

---

## 🔧 Próximos Pasos

1. **Confirmar Arquitectura**: ¿3 o 4 EC2?
2. **Crear Scripts de Setup Automatizados**
3. **Implementar Data Producer**
4. **Configurar Flink Streaming Jobs**
5. **Implementar Spark Batch Jobs**
6. **Configurar PostgreSQL + Superset**
7. **Testing y Optimización**
8. **Documentación Final**

---

## ❓ Preguntas Pendientes

1. ¿Confirmas 4 EC2 o prefieres optimizar a 3?
2. ¿Tienes ya las cuentas de AWS Academy configuradas?
3. ¿Prefieres que genere todos los scripts ahora o paso a paso?
4. ¿Alguna métrica específica adicional que quieras en los dashboards?
