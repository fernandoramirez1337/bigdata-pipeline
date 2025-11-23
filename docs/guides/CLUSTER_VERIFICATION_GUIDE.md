# Guía de Verificación del Cluster

## Scripts de Verificación Disponibles

Hemos creado dos scripts completos para verificar la correcta distribución y conexión entre los nodos del cluster:

### 1. 🎨 `cluster-dashboard.sh` - Dashboard Visual

**Propósito**: Vista rápida y visual del estado del cluster

**Uso**:
```bash
./infrastructure/scripts/cluster-dashboard.sh
```

**Qué muestra**:
- ✅ Topología del cluster (diagrama ASCII)
- ✅ Estado de conectividad de cada nodo
- ✅ Estado de todos los servicios (Java processes)
- ✅ Estado del cluster HDFS (NameNode + DataNodes)
- ✅ Estado del cluster Spark (Master + Workers)
- ✅ Estado del cluster Flink (JobManager + TaskManagers)
- ✅ Estado de Kafka y Zookeeper (con lista de topics)
- ✅ Estado de PostgreSQL (con lista de databases)
- ✅ URLs de todas las Web UIs

**Tiempo de ejecución**: ~10 segundos

**Ideal para**:
- Verificación rápida del estado general
- Monitoreo diario
- Demostración del cluster

---

### 2. 🔍 `verify-cluster-health.sh` - Verificación Completa

**Propósito**: Diagnóstico exhaustivo de conectividad y comunicación

**Uso**:
```bash
./infrastructure/scripts/verify-cluster-health.sh
```

**Qué verifica** (10 categorías de tests):

#### TEST 1: SSH Connectivity
- Verifica que se puede conectar por SSH a los 4 nodos

#### TEST 2: Internal Network Connectivity
- Prueba ping entre todos los nodos usando IPs privadas
- Master → Workers/Storage
- Workers → Master/otros Workers/Storage

#### TEST 3: Hostname Resolution
- Verifica que `/etc/hosts` está correctamente configurado
- Prueba resolución de hostnames (master-node, worker1-node, etc.)

#### TEST 4: Java Processes (jps)
- Verifica que todos los procesos Java están corriendo
- Master: NameNode, Kafka, Zookeeper, Spark Master, Flink JobManager
- Workers: DataNode, Spark Worker, Flink TaskManager
- Storage: DataNode, PostgreSQL

#### TEST 5: HDFS Cluster Status
- Verifica que NameNode está activo
- Cuenta DataNodes conectados (debe ser 3)
- Verifica que cada DataNode está registrado

#### TEST 6: HDFS Port Connectivity
- Prueba conectividad TCP a puerto 9000 desde cada DataNode
- Verifica que NameNode está escuchando en `0.0.0.0:9000` (no `127.0.0.1`)

#### TEST 7: Spark Cluster Status
- Consulta Spark Master Web UI
- Verifica cantidad de Workers conectados (debe ser 2)
- Prueba conectividad TCP a puerto 7077

#### TEST 8: Flink Cluster Status
- Consulta Flink JobManager API REST
- Verifica cantidad de TaskManagers conectados (debe ser 2)
- Prueba conectividad TCP a puerto 6123

#### TEST 9: Kafka & Zookeeper Status
- Verifica que Zookeeper responde (`echo stat | nc localhost 2181`)
- Verifica que Kafka responde y cuenta topics

#### TEST 10: PostgreSQL Status
- Prueba conexión a PostgreSQL
- Verifica que databases `superset` y `taxi_analytics` existen

**Salida**:
```
TEST SUMMARY
════════════════════════════════════════
Total Tests:    85
Passed:         82 ✅
Failed:         0 ❌
Warnings:       3 ⚠️

🎉 CLUSTER HEALTH: EXCELLENT
All nodes are connected and communicating correctly!
```

**Tiempo de ejecución**: ~30-45 segundos

**Ideal para**:
- Troubleshooting de problemas
- Verificación después de cambios de configuración
- Validación después de reiniciar servicios
- Diagnóstico de problemas de red

---

## Comparación de Scripts

| Característica | cluster-dashboard.sh | verify-cluster-health.sh |
|----------------|---------------------|-------------------------|
| **Velocidad** | ⚡ Rápido (~10s) | 🔍 Completo (~40s) |
| **Propósito** | Vista general | Diagnóstico profundo |
| **Output** | Visual/Dashboard | Tests detallados |
| **Tests** | Estado de servicios | Conectividad + Servicios |
| **Uso diario** | ✅ Ideal | Solo cuando hay problemas |
| **Debugging** | ❌ Limitado | ✅ Exhaustivo |

---

## Casos de Uso Comunes

### Caso 1: Verificación Matutina
```bash
# Dashboard rápido para ver que todo está bien
./infrastructure/scripts/cluster-dashboard.sh
```

### Caso 2: Después de Reiniciar Servicios
```bash
# Verificación completa para asegurar que todo se reconectó
./infrastructure/scripts/verify-cluster-health.sh
```

### Caso 3: Troubleshooting de DataNodes
```bash
# Si HDFS muestra problemas, ejecutar verificación completa
./infrastructure/scripts/verify-cluster-health.sh

# Revisar específicamente TEST 5 y TEST 6
# Si falla TEST 6, hay problema de conectividad de red
```

### Caso 4: Después de Cambios de Configuración
```bash
# Verificar que los cambios no rompieron nada
./infrastructure/scripts/verify-cluster-health.sh

# Si hay fallos, revisar logs específicos:
# - HDFS: /var/log/bigdata/hadoop/
# - Kafka: /var/log/bigdata/kafka.log
# - Otros: journalctl -u <service>
```

### Caso 5: Antes de Procesar Datos Críticos
```bash
# Asegurar que el cluster está 100% saludable
./infrastructure/scripts/verify-cluster-health.sh

# Solo proceder si sale: "CLUSTER HEALTH: EXCELLENT"
```

---

## Interpretando Resultados

### Estados Posibles

#### ✅ EXCELLENT (Verde)
- Todos los tests pasaron
- Sin warnings
- Cluster 100% operacional
- **Acción**: Ninguna

#### ⚠️ GOOD (Amarillo)
- Todos los tests pasaron
- Algunos warnings
- Cluster funcional pero con componentes opcionales apagados
- **Acción**: Revisar warnings, no crítico

#### ❌ ISSUES DETECTED (Rojo)
- Algunos tests fallaron
- Cluster no está completamente operacional
- **Acción**: Revisar tests fallidos y corregir

---

## Qué Hacer si Hay Fallos

### Fallo en TEST 1 (SSH Connectivity)
```bash
# Problema: No se puede conectar por SSH
# Solución: Verificar que instancias EC2 están running
aws ec2 describe-instances --instance-ids <instance-id>
```

### Fallo en TEST 2 (Network Connectivity)
```bash
# Problema: Nodos no pueden hacer ping entre sí
# Solución 1: Verificar Security Groups de AWS
# Solución 2: Verificar que /etc/hosts está correcto
ssh -i ~/.ssh/bigd-key.pem ec2-user@<node-ip> "cat /etc/hosts"
```

### Fallo en TEST 5 (HDFS Cluster)
```bash
# Problema: DataNodes no están conectados
# Verificar logs de DataNodes:
ssh -i ~/.ssh/bigd-key.pem ec2-user@<worker-ip>
tail -100 /var/log/bigdata/hadoop/hadoop-*-datanode-*.log

# Solución común: Reiniciar DataNodes
ssh -i ~/.ssh/bigd-key.pem ec2-user@<worker-ip>
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop datanode
$HADOOP_HOME/bin/hdfs --daemon start datanode
```

### Fallo en TEST 6 (HDFS Port Connectivity)
```bash
# Problema: Puerto 9000 no es accesible
# Diagnóstico 1: Verificar que NameNode está escuchando en 0.0.0.0
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
sudo netstat -tulnp | grep 9000

# Si muestra 127.0.0.1:9000 (MAL):
./infrastructure/scripts/fix-namenode-binding.sh

# Diagnóstico 2: Verificar AWS Security Groups
# Ver: docs/AWS_SECURITY_GROUP_FIX.md
```

### Fallo en TEST 7/8 (Spark/Flink)
```bash
# Problema: Workers/TaskManagers no conectados
# Solución: Reiniciar servicios en orden

# Spark:
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
source /etc/profile.d/bigdata.sh
$SPARK_HOME/sbin/stop-worker.sh
$SPARK_HOME/sbin/start-worker.sh spark://master-node:7077

# Flink:
ssh -i ~/.ssh/bigd-key.pem ec2-user@<worker-ip>
source /etc/profile.d/bigdata.sh
$FLINK_HOME/bin/taskmanager.sh stop
$FLINK_HOME/bin/taskmanager.sh start
```

---

## Automatización (Opcional)

### Cron Job para Monitoreo Diario

```bash
# Agregar a crontab en tu máquina local
# Ejecuta el dashboard cada día a las 9 AM
0 9 * * * /path/to/bigdata-pipeline/infrastructure/scripts/cluster-dashboard.sh > /tmp/cluster-status.log 2>&1

# Si quieres recibir email cuando hay fallos:
0 9 * * * /path/to/bigdata-pipeline/infrastructure/scripts/verify-cluster-health.sh || mail -s "Cluster Health Issues" your@email.com < /tmp/cluster-status.log
```

### Script de Alerta

```bash
#!/bin/bash
# check-and-alert.sh

./infrastructure/scripts/verify-cluster-health.sh
EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ]; then
    echo "Cluster health check failed!" | mail -s "ALERT: Cluster Issues Detected" admin@example.com

    # Opcional: Reiniciar servicios automáticamente
    # ./infrastructure/scripts/restart-all-services.sh
fi
```

---

## Métricas de Salud del Cluster

### Cluster Saludable (Expected)
```
✅ SSH Connectivity:         4/4 nodes
✅ Network Connectivity:    12/12 paths
✅ Hostname Resolution:      6/6 hosts
✅ Java Processes:          12/12 services
✅ HDFS DataNodes:           3/3 connected
✅ HDFS Port Connectivity:   3/3 reachable
✅ Spark Workers:            2/2 connected
✅ Flink TaskManagers:       2/2 connected
✅ Kafka/Zookeeper:          2/2 running
✅ PostgreSQL:               1/1 running
```

### Signos de Problemas

| Síntoma | Causa Probable | Severidad |
|---------|---------------|-----------|
| DataNodes: 0/3 | NameNode binding o red | 🔴 Crítico |
| DataNodes: 1-2/3 | Worker específico apagado | 🟡 Medio |
| Spark Workers: 0-1/2 | Spark Worker apagado | 🟡 Medio |
| Kafka no responde | Zookeeper apagado | 🔴 Crítico |
| PostgreSQL no responde | Servicio apagado | 🟡 Medio |

---

## Logs de Diagnóstico

Si los scripts reportan problemas, revisar estos logs:

```bash
# HDFS
/var/log/bigdata/hadoop/hadoop-*-namenode-*.log
/var/log/bigdata/hadoop/hadoop-*-datanode-*.log

# Kafka
/var/log/bigdata/kafka.log

# Zookeeper
/var/log/bigdata/zookeeper/zookeeper.log

# Spark
/opt/bigdata/spark/logs/

# Flink
/opt/bigdata/flink/log/

# PostgreSQL
/var/log/postgresql/
sudo journalctl -u postgresql

# Superset
/var/log/bigdata/superset.log
```

---

## Referencias

- **Documentación completa**: `docs/PROBLEMS_FIXED.md`
- **Fix de HDFS**: `docs/HDFS_NAMENODE_BINDING_FIX.md`
- **Security Groups**: `docs/AWS_SECURITY_GROUP_FIX.md`
- **Quick Start**: `QUICK_START.md`

---

**Última actualización**: 20 de Noviembre 2025
**Mantenedor**: DevOps Team
**Versión**: 1.0
