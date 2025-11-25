# 🔄 Flink Streaming Setup Guide

## 🎯 Objetivo

Implementar streaming en tiempo real para procesar datos de taxis que llegan constantemente y actualizar dashboards automáticamente.

---

## 📊 Arquitectura del Streaming Pipeline

```
Kafka Topic          Flink Job           PostgreSQL        Superset
(taxi-events)   →   (Processing)   →   (real_time_zones)  →  (Dashboard)
```

### Flujo de Datos

1. **Producer** → Simula viajes de taxi y los envía a Kafka
2. **Kafka** → Buffer de eventos en tiempo real
3. **Flink** → Procesa ventanas de tiempo y agrega datos
4. **PostgreSQL** → Almacena agregaciones en tiempo real
5. **Superset** → Visualiza datos con auto-refresh

---

## 🚀 PASO 1: Crear Kafka Topic

### Conectarse al Master Node

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.192.13.83
```

### Crear Topic para Taxi Events

```bash
source /etc/profile.d/bigdata.sh

# Crear topic
$KAFKA_HOME/bin/kafka-topics.sh \
  --create \
  --bootstrap-server localhost:9092 \
  --topic taxi-events \
  --partitions 3 \
  --replication-factor 1

# Verificar topic creado
$KAFKA_HOME/bin/kafka-topics.sh \
  --list \
  --bootstrap-server localhost:9092
```

---

## 📝 PASO 2: Preparar PostgreSQL Table

### Crear Tabla para Datos en Tiempo Real

```sql
-- Ejecutar en PostgreSQL (Storage Node)
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.90.201.110

PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi << 'EOF'

CREATE TABLE IF NOT EXISTS real_time_zones (
    window_start TIMESTAMP NOT NULL,
    window_end TIMESTAMP NOT NULL,
    zone_id VARCHAR(10) NOT NULL,
    trip_count BIGINT DEFAULT 0,
    total_revenue DECIMAL(12, 2) DEFAULT 0,
    avg_fare DECIMAL(8, 2) DEFAULT 0,
    avg_distance DECIMAL(8, 2) DEFAULT 0,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (window_start, zone_id)
);

-- Índice para queries rápidas
CREATE INDEX idx_realtime_window ON real_time_zones(window_start DESC);
CREATE INDEX idx_realtime_zone ON real_time_zones(zone_id);

-- Vista para últimas 24 horas
CREATE OR REPLACE VIEW v_realtime_last_24h AS
SELECT *
FROM real_time_zones
WHERE window_start >= NOW() - INTERVAL '24 hours'
ORDER BY window_start DESC, trip_count DESC;

EOF
```

---

## 🔧 PASO 3: Configurar Flink Job

### Estructura del Flink Job

El job de Flink hará:

1. **Consumir** eventos de Kafka topic `taxi-events`
2. **Parsear** JSON events
3. **Agregar** por ventanas de tiempo (5 minutos)
4. **Calcular** métricas (count, sum, avg)
5. **Escribir** a PostgreSQL

### Configuración Maven (pom.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.bigdata</groupId>
    <artifactId>taxi-streaming</artifactId>
    <version>1.0-SNAPSHOT</version>

    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <flink.version>1.18.0</flink.version>
        <scala.binary.version>2.12</scala.binary.version>
    </properties>

    <dependencies>
        <!-- Flink Dependencies -->
        <dependency>
            <groupId>org.apache.flink</groupId>
            <artifactId>flink-streaming-java</artifactId>
            <version>${flink.version}</version>
        </dependency>
        <dependency>
            <groupId>org.apache.flink</groupId>
            <artifactId>flink-connector-kafka</artifactId>
            <version>${flink.version}</version>
        </dependency>
        <dependency>
            <groupId>org.apache.flink</groupId>
            <artifactId>flink-connector-jdbc</artifactId>
            <version>3.1.1-1.17</version>
        </dependency>
        
        <!-- PostgreSQL Driver -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <version>42.6.0</version>
        </dependency>
        
        <!-- JSON Processing -->
        <dependency>
            <groupId>com.fasterxml.jackson.core</groupId>
            <artifactId>jackson-databind</artifactId>
            <version>2.15.2</version>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.5.0</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
```

---

## 📊 PASO 4: Generador de Datos (Producer)

### Script Python para Simular Taxi Events

Ver: `streaming/producer/taxi_event_generator.py`

Este script:
- Genera eventos de taxi aleatorios
- Los envía a Kafka topic
- Simula tráfico realista

### Ejecutar Producer

```bash
cd streaming/producer
python3 taxi_event_generator.py --rate 100  # 100 eventos/segundo
```

---

## 🚀 PASO 5: Desplegar Flink Job

### Compilar Job

```bash
cd streaming/flink-jobs
mvn clean package
```

### Submit a Flink Cluster

```bash
# Desde tu máquina local
scp -i ~/.ssh/bigd-key.pem \
  target/taxi-streaming-1.0-SNAPSHOT.jar \
  ec2-user@44.192.13.83:~/

# En el Master Node
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.192.13.83

source /etc/profile.d/bigdata.sh

$FLINK_HOME/bin/flink run \
  -c com.bigdata.TaxiStreamingJob \
  ~/taxi-streaming-1.0-SNAPSHOT.jar
```

### Verificar Job Corriendo

- Flink UI: http://44.192.13.83:8081
- Ver jobs activos
- Monitorear métricas

---

## 📊 PASO 6: Dashboard en Superset

### Agregar Dataset Real-Time

1. Superset → **Data** → **Datasets** → **+ Dataset**
2. Table: `real_time_zones` o `v_realtime_last_24h`

### Charts Sugeridos

#### 1. Real-Time Trip Count (Last Hour)

- **Type:** Time-series Bar Chart
- **Time Column:** window_start
- **Metric:** SUM(trip_count)
- **Time Grain:** 5 minutes
- **Time Range:** Last 1 hour

#### 2. Top Zones (Real-Time)

- **Type:** Bar Chart
- **Dimension:** zone_id
- **Metric:** SUM(trip_count)
- **Sort:** Descending
- **Limit:** 10

#### 3. Revenue Stream

- **Type:** Line Chart (Smooth)
- **Time Column:** window_start
- **Metric:** SUM(total_revenue)
- **Auto-refresh:** Every 30 seconds

---

## 🔍 Monitoreo y Troubleshooting

### Ver Logs de Flink

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.192.13.83
tail -f /opt/bigdata/flink/log/flink-*-jobmanager-*.log
```

### Ver Datos en PostgreSQL

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.90.201.110

PGPASSWORD=bigdata123 psql -U bigdata -d bigdata_taxi -c \
  "SELECT * FROM v_realtime_last_24h LIMIT 10;"
```

### Verificar Kafka Consumer Lag

```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.192.13.83

source /etc/profile.d/bigdata.sh

$KAFKA_HOME/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --group flink-taxi-consumer \
  --describe
```

---

## 📈 Optimizaciones

### Checkpointing

```java
env.enableCheckpointing(60000); // Checkpoint cada 60 segundos
env.getCheckpointConfig().setMinPauseBetweenCheckpoints(30000);
```

### Paralelismo

```bash
$FLINK_HOME/bin/flink run \
  -p 4 \  # Paralelismo 4
  -c com.bigdata.TaxiStreamingJob \
  ~/taxi-streaming-1.0-SNAPSHOT.jar
```

---

## 🛑 Detener Streaming

### Cancel Flink Job

```bash
# Listar jobs
$FLINK_HOME/bin/flink list

# Cancelar job
$FLINK_HOME/bin/flink cancel <JOB_ID>
```

### Detener Producer

```bash
# Ctrl+C en la terminal del producer
```

---

## 📚 Recursos

- [Flink Documentation](https://nightlies.apache.org/flink/flink-docs-stable/)
- [Kafka Connector](https://nightlies.apache.org/flink/flink-docs-stable/docs/connectors/datastream/kafka/)
- [JDBC Connector](https://nightlies.apache.org/flink/flink-docs-stable/docs/connectors/datastream/jdbc/)

---

**Última actualización:** Noviembre 24, 2025
