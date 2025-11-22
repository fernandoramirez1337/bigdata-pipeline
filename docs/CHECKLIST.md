# Checklist de Implementación - Big Data Pipeline

## 📋 Progreso General

- [x] **Fase 1: Infraestructura** (100%)
- [x] **Fase 2: Instalación Base** (100%)
- [ ] **Fase 3: Instalación Software Big Data** (20% - En progreso)
- [ ] **Fase 4: Configuración de Servicios** (0%)
- [ ] **Fase 5: Despliegue de Pipeline** (0%)
- [ ] **Fase 6: Validación y Pruebas** (0%)

---

## ✅ Fase 1: Infraestructura AWS (COMPLETADO)

### 1.1 Creación de EC2 Instances
- [x] Crear 4 instancias EC2 con `create-cluster.sh`
- [x] Verificar instancias creadas correctamente
- [x] Anotar IPs públicas y privadas
- [x] Generar archivo `cluster-info.txt`

**Instancias creadas**:
```
Master:  i-095692309cc67a77e (t3.small)      - 172.31.72.49  / 44.210.18.254
Worker1: i-09a02241a47abc50d (c7i-flex.large) - 172.31.70.167 / 44.221.77.132
Worker2: i-0d0535e69242b7db5 (c7i-flex.large) - 172.31.15.51  / 3.219.215.11
Storage: i-05ebe42a3698b6b71 (m7i-flex.large) - 172.31.31.171 / 98.88.249.180
```

### 1.2 Security Group
- [x] Crear Security Group `bigdata-cluster-sg`
- [x] Configurar reglas de ingress (SSH, Web UIs, servicios internos)
- [x] Configurar regla para comunicación intra-cluster

### 1.3 Configuración de Red
- [x] Configurar `/etc/hosts` en Master
- [x] Configurar `/etc/hosts` en Worker1
- [x] Configurar `/etc/hosts` en Worker2
- [x] Configurar `/etc/hosts` en Storage
- [x] Verificar conectividad con `ping` entre nodos
- [x] Actualizar IPs en `orchestrate-cluster.sh`

### 1.4 Acceso SSH
- [x] Verificar acceso SSH a Master
- [x] Verificar acceso SSH a Worker1
- [x] Verificar acceso SSH a Worker2
- [x] Verificar acceso SSH a Storage

---

## ✅ Fase 2: Instalación Base (COMPLETADO)

### 2.1 Common Setup (Todas las instancias)
- [x] Actualizar paquetes del sistema
- [x] Instalar Java 11 Amazon Corretto
- [x] Configurar JAVA_HOME
- [x] Instalar utilidades esenciales (git, wget, htop, etc.)
- [x] Crear estructura de directorios (`/opt/bigdata`, `/data/*`)
- [x] Configurar límites del sistema (nofile, nproc)
- [x] Deshabilitar Transparent Huge Pages
- [x] Configurar swappiness
- [x] Instalar paquetes Python (kafka-python, pandas, boto3, etc.)

### 2.2 Resolución de Problemas
- [x] Identificar conflicto de paquete curl
- [x] Remover curl de script de instalación
- [x] Commit y push del fix
- [x] Verificar instalación exitosa post-fix

---

## ⏳ Fase 3: Software Big Data (20% - EN PROGRESO)

### 3.1 Master Node
- [x] Descargar Apache Zookeeper 3.8.3
- [ ] Extraer y configurar Zookeeper
- [x] Descargar Apache Kafka 3.6.0 (EN PROGRESO ~7%)
- [ ] Extraer y configurar Kafka
- [ ] Descargar Apache Flink 1.18.0
- [ ] Configurar Flink JobManager
- [ ] Descargar Apache Spark 3.5.0
- [ ] Configurar Spark Master
- [ ] Descargar Hadoop HDFS 3.3.6
- [ ] Configurar HDFS NameNode

### 3.2 Worker Nodes (Worker1 & Worker2)
- [ ] Descargar Apache Flink 1.18.0
- [ ] Configurar Flink TaskManager
- [ ] Descargar Apache Spark 3.5.0
- [ ] Configurar Spark Worker
- [ ] Descargar Hadoop HDFS 3.3.6
- [ ] Configurar HDFS DataNode

### 3.3 Storage Node
- [ ] Instalar PostgreSQL 15
- [ ] Configurar PostgreSQL
- [ ] Instalar Apache Superset 3.1.0
- [ ] Descargar Hadoop HDFS 3.3.6
- [ ] Configurar HDFS DataNode
- [ ] Instalar AWS CLI v2

**Tiempo estimado restante**: 25-35 minutos

---

## 📦 Fase 4: Configuración de Servicios (PENDIENTE)

### 4.1 Iniciar Servicios Base

#### Master
- [ ] Iniciar Zookeeper
- [ ] Verificar Zookeeper (zkServer.sh status)
- [ ] Iniciar Kafka
- [ ] Verificar Kafka (listar brokers)
- [ ] Iniciar HDFS NameNode
- [ ] Verificar HDFS NameNode Web UI (9870)
- [ ] Iniciar Flink JobManager
- [ ] Verificar Flink Dashboard (8081)
- [ ] Iniciar Spark Master
- [ ] Verificar Spark Web UI (8080)

#### Workers
- [ ] Iniciar HDFS DataNode en Worker1
- [ ] Iniciar HDFS DataNode en Worker2
- [ ] Verificar DataNodes en HDFS Web UI
- [ ] Iniciar Flink TaskManager en Worker1
- [ ] Iniciar Flink TaskManager en Worker2
- [ ] Verificar TaskManagers en Flink Dashboard
- [ ] Iniciar Spark Worker en Worker1
- [ ] Iniciar Spark Worker en Worker2
- [ ] Verificar Workers en Spark Web UI

#### Storage
- [ ] Iniciar PostgreSQL
- [ ] Iniciar HDFS DataNode
- [ ] Iniciar Superset
- [ ] Verificar Superset Web UI (8088)

### 4.2 Verificar Estado del Cluster
- [ ] Verificar todos los procesos con `jps`
- [ ] Ejecutar `orchestrate-cluster.sh status`
- [ ] Verificar logs de errores
- [ ] Acceder a todas las Web UIs

### 4.3 Configurar Kafka
- [ ] Crear topic `taxi-trips`
- [ ] Configurar particiones (3)
- [ ] Configurar replication factor (1)
- [ ] Verificar topic creado
- [ ] Probar producer/consumer básico

### 4.4 Configurar PostgreSQL
- [ ] Crear database `taxi_analytics`
- [ ] Crear usuario `bigdata`
- [ ] Configurar permisos
- [ ] Crear tabla `zone_metrics`
- [ ] Crear índices
- [ ] Probar conexión desde Master

### 4.5 Inicializar Superset
- [ ] Crear usuario admin
- [ ] Inicializar base de datos
- [ ] Configurar roles
- [ ] Agregar conexión a PostgreSQL
- [ ] Probar login

---

## 🚀 Fase 5: Despliegue de Pipeline (PENDIENTE)

### 5.1 Preparar Dataset
- [ ] Descargar NYC Taxi dataset 2015 (12 meses)
- [ ] Verificar archivos descargados (~40-60 GB)
- [ ] Subir a HDFS `/taxi/raw/`
- [ ] Verificar replicación en HDFS

### 5.2 Data Producer
- [ ] Copiar código a Master
- [ ] Configurar `config.yaml`
- [ ] Probar producer con 1000 registros
- [ ] Iniciar producer en background
- [ ] Verificar mensajes en Kafka topic

### 5.3 Flink Streaming Job
- [ ] Compilar job con Maven
- [ ] Verificar JAR generado
- [ ] Desplegar job en Flink cluster
- [ ] Verificar job en Flink Dashboard
- [ ] Verificar registros en PostgreSQL
- [ ] Monitorear métricas

### 5.4 Spark Batch Jobs
- [ ] Copiar scripts a Master
- [ ] Configurar paths de HDFS
- [ ] Ejecutar job de prueba manualmente
- [ ] Verificar resultados en HDFS
- [ ] Configurar cron para ejecución diaria
- [ ] Verificar primera ejecución automática

### 5.5 Superset Dashboards
- [ ] Crear dataset de `zone_metrics`
- [ ] Crear chart: Viajes por minuto (Line Chart)
- [ ] Crear chart: Top 10 zonas (Bar Chart)
- [ ] Crear chart: Distribución pagos (Pie Chart)
- [ ] Crear chart: Ingresos totales (Big Number)
- [ ] Crear chart: Métricas promedio (Table)
- [ ] Crear Dashboard principal
- [ ] Configurar auto-refresh
- [ ] Tomar screenshots

---

## ✅ Fase 6: Validación y Pruebas (PENDIENTE)

### 6.1 Pruebas de Streaming
- [ ] Verificar latencia end-to-end (<5 segundos)
- [ ] Verificar throughput (~1000 eventos/segundo)
- [ ] Probar failover de Flink TaskManager
- [ ] Verificar exactly-once semantics
- [ ] Validar datos en PostgreSQL vs Kafka

### 6.2 Pruebas de Batch
- [ ] Ejecutar job de resumen diario
- [ ] Verificar tiempo de procesamiento
- [ ] Validar resultados en HDFS
- [ ] Comparar métricas batch vs streaming
- [ ] Probar recovery de job fallido

### 6.3 Pruebas de Sistema
- [ ] Simular fallo de Worker node
- [ ] Verificar redistribución de tareas
- [ ] Probar reinicio de servicios
- [ ] Validar persistencia de datos
- [ ] Monitorear uso de recursos

### 6.4 Métricas de Rendimiento
- [ ] Medir latencia de streaming (p50, p99)
- [ ] Medir throughput sostenido
- [ ] Medir tiempo de batch processing
- [ ] Medir uso de CPU por servicio
- [ ] Medir uso de RAM por servicio
- [ ] Medir uso de red
- [ ] Medir uso de disco

### 6.5 Documentación Final
- [ ] Capturar screenshots de dashboards
- [ ] Documentar métricas reales
- [ ] Actualizar README con resultados
- [ ] Crear guía de operación
- [ ] Documentar lecciones aprendidas

---

## 🔧 Comandos Rápidos

### Verificar Estado
```bash
# Estado completo del cluster
./orchestrate-cluster.sh status

# Procesos Java en cada nodo
ssh ec2-user@<NODE_IP> "jps -l"

# Web UIs
open http://44.210.18.254:9870  # HDFS
open http://44.210.18.254:8080  # Spark
open http://44.210.18.254:8081  # Flink
open http://98.88.249.180:8088  # Superset
```

### Iniciar/Detener
```bash
# Iniciar todo
./orchestrate-cluster.sh start-cluster

# Detener todo
./orchestrate-cluster.sh stop-cluster

# Reiniciar servicio específico
ssh ec2-user@44.210.18.254
/opt/bigdata/kafka-3.6.0/bin/kafka-server-stop.sh
/opt/bigdata/kafka-3.6.0/bin/kafka-server-start.sh -daemon \
  /opt/bigdata/kafka-3.6.0/config/server.properties
```

### Monitoreo
```bash
# Logs de Kafka
tail -f /opt/bigdata/kafka-3.6.0/logs/server.log

# Logs de Flink
tail -f /opt/bigdata/flink-1.18.0/log/flink-*-standalonesession-*.log

# Logs de producer
tail -f /var/log/bigdata/producer.log

# PostgreSQL queries
ssh ec2-user@98.88.249.180
psql -U bigdata -d taxi_analytics -c "SELECT COUNT(*) FROM zone_metrics;"
```

---

## 📊 Progreso por Componente

| Componente | Estado | Progreso | Comentarios |
|------------|--------|----------|-------------|
| **EC2 Instances** | ✅ Listo | 100% | 4 instancias operativas |
| **Networking** | ✅ Listo | 100% | Security Group + /etc/hosts |
| **Java** | ✅ Listo | 100% | Amazon Corretto 11 |
| **Python** | ✅ Listo | 100% | Python 3.9 + packages |
| **Zookeeper** | ⏳ Descargando | 100% | Archivo descargado |
| **Kafka** | ⏳ Descargando | 7% | 108 MB, ~12 min restantes |
| **Flink** | ⏸️ Pendiente | 0% | Esperando Kafka |
| **Spark** | ⏸️ Pendiente | 0% | Esperando Flink |
| **HDFS** | ⏸️ Pendiente | 0% | Esperando Spark |
| **PostgreSQL** | ⏸️ Pendiente | 0% | Instalación en Storage |
| **Superset** | ⏸️ Pendiente | 0% | Instalación en Storage |
| **Data Producer** | ⏸️ Pendiente | 0% | Código listo, falta config |
| **Flink Jobs** | ⏸️ Pendiente | 0% | Código listo, falta compilar |
| **Spark Jobs** | ⏸️ Pendiente | 0% | Código listo, falta copiar |
| **Dashboards** | ⏸️ Pendiente | 0% | Pendiente Superset |

---

## ⏰ Timeline Estimado

| Fase | Duración Estimada | Completado | Restante |
|------|------------------|------------|----------|
| Fase 1: Infraestructura | 30 min | ✅ 30 min | - |
| Fase 2: Instalación Base | 45 min | ✅ 45 min | - |
| Fase 3: Software Big Data | 60 min | ⏳ 12 min | ~48 min |
| Fase 4: Config Servicios | 45 min | - | 45 min |
| Fase 5: Despliegue Pipeline | 90 min | - | 90 min |
| Fase 6: Validación | 60 min | - | 60 min |
| **TOTAL** | **5.5 horas** | **1.5 horas** | **4 horas** |

---

## 🎯 Próximos 3 Pasos Inmediatos

1. **ESPERAR** → Completar instalación automática (~30-40 min)
   ```bash
   # Verificar cuando termine
   ./orchestrate-cluster.sh status
   ```

2. **INICIAR SERVICIOS** → Arrancar todo el cluster
   ```bash
   ./orchestrate-cluster.sh start-cluster
   ```

3. **VERIFICAR** → Acceder a Web UIs y confirmar funcionamiento
   ```
   http://44.210.18.254:9870  # HDFS
   http://44.210.18.254:8080  # Spark
   http://44.210.18.254:8081  # Flink
   ```

---

**Última actualización**: 20 Nov 2025, 15:10 UTC
**Estado actual**: Instalación de Kafka en progreso (~7%)
**Siguiente milestone**: Completar instalación de software Big Data
