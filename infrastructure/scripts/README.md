# Infrastructure Scripts

Scripts para crear y gestionar el cluster de Big Data en AWS.

## Scripts Disponibles

### 1. create-cluster.sh

**Crea automáticamente las 4 instancias EC2 con Security Group configurado.**

#### Uso Básico

```bash
# Con configuración por defecto
./create-cluster.sh

# O con variables personalizadas
export KEY_NAME="tu-key"
export MY_IP="201.230.200.80/32"  # Tu IP para SSH
./create-cluster.sh
```

#### Variables de Entorno

| Variable | Por Defecto | Descripción |
|----------|-------------|-------------|
| `KEY_NAME` | `bigd-key` | Nombre de tu SSH key pair en AWS |
| `AMI_ID` | `ami-0453ec754f44f9a4a` | Amazon Linux 2023 (us-east-1) |
| `MY_IP` | `0.0.0.0/0` | Tu IP para acceso SSH (usa tu IP para seguridad) |
| `AWS_REGION` | `us-east-1` | Región de AWS |

#### Lo que hace

1. ✅ Verifica que tu SSH key existe
2. ✅ Obtiene información de tu VPC por defecto
3. ✅ Crea Security Group con reglas configuradas
4. ✅ Lanza 4 instancias EC2:
   - **bigdata-master**: t3.large, 100 GB
   - **bigdata-worker1**: t3.xlarge, 200 GB
   - **bigdata-worker2**: t3.xlarge, 200 GB
   - **bigdata-storage**: t3.large, 150 GB
5. ✅ Genera archivo `cluster-info.txt` con toda la información

#### Salida

```
========================================
¡Cluster creado exitosamente!
========================================

Instancias creadas:
bigdata-master   i-0abc123  t3.large   172.31.1.10  54.123.45.67
bigdata-worker1  i-0abc124  t3.xlarge  172.31.1.11  54.123.45.68
bigdata-worker2  i-0abc125  t3.xlarge  172.31.1.12  54.123.45.69
bigdata-storage  i-0abc126  t3.large   172.31.1.13  54.123.45.70
```

El script también crea `cluster-info.txt` con:
- IPs públicas y privadas
- Comandos SSH para conectarse
- URLs de Web UIs
- Configuración para /etc/hosts
- Variables para orchestrate-cluster.sh

---

### 2. orchestrate-cluster.sh

**Orquesta la instalación y gestión del cluster completo.**

#### Comandos Disponibles

```bash
# Probar conectividad a todas las instancias
./orchestrate-cluster.sh test-connectivity

# Instalar todo el software en las 4 EC2 (toma ~30-45 min)
./orchestrate-cluster.sh setup-all

# Iniciar todos los servicios
./orchestrate-cluster.sh start-cluster

# Detener todos los servicios
./orchestrate-cluster.sh stop-cluster

# Ver estado de servicios
./orchestrate-cluster.sh status

# Crear topics de Kafka
./orchestrate-cluster.sh create-topics
```

#### Configuración Requerida

**ANTES de ejecutar**, editar el script y actualizar IPs:

```bash
vim orchestrate-cluster.sh

# Líneas 25-28:
MASTER_IP="172.31.1.10"    # IP privada de EC2-1
WORKER1_IP="172.31.1.11"   # IP privada de EC2-2
WORKER2_IP="172.31.1.12"   # IP privada de EC2-3
STORAGE_IP="172.31.1.13"   # IP privada de EC2-4

# Línea 30:
SSH_KEY="~/.ssh/bigd-key.pem"
```

💡 **Tip**: Copia las IPs desde `cluster-info.txt` generado por `create-cluster.sh`

---

### 3. common-setup.sh

**Setup común para todas las instancias.**

Instala:
- Java 11
- Python 3 + pip
- Utilidades (wget, curl, git, htop, etc.)
- Configuraciones del sistema (límites, swappiness, etc.)

**Uso**: Ejecutado automáticamente por `orchestrate-cluster.sh` o `setup-*.sh`

---

### 4. setup-master.sh

**Instala componentes del nodo Master (EC2-1).**

Instala y configura:
- Apache Zookeeper 3.8.3
- Apache Kafka 3.6.0
- Apache Flink 1.18.0 (JobManager)
- Apache Spark 3.5.0 (Master)
- Hadoop HDFS 3.3.6 (NameNode)

**Uso**:
```bash
# SSH a Master
ssh -i ~/.ssh/bigd-key.pem ec2-user@<MASTER_PUBLIC_IP>

# Copiar scripts
scp -i ~/.ssh/bigd-key.pem common-setup.sh setup-master.sh ec2-user@<MASTER_IP>:~

# Ejecutar
bash common-setup.sh
bash setup-master.sh
```

---

### 5. setup-worker.sh

**Instala componentes de los nodos Worker (EC2-2, EC2-3).**

Instala y configura:
- Apache Flink 1.18.0 (TaskManager)
- Apache Spark 3.5.0 (Worker)
- Hadoop HDFS 3.3.6 (DataNode)

**Uso**:
```bash
# SSH a Worker
ssh -i ~/.ssh/bigd-key.pem ec2-user@<WORKER_PUBLIC_IP>

# Copiar scripts
scp -i ~/.ssh/bigd-key.pem common-setup.sh setup-worker.sh ec2-user@<WORKER_IP>:~

# Ejecutar (pasar 1 para worker1, 2 para worker2)
bash common-setup.sh
bash setup-worker.sh 1  # o 2 para worker2
```

---

### 6. setup-storage.sh

**Instala componentes del nodo Storage (EC2-4).**

Instala y configura:
- PostgreSQL 15
- Apache Superset 3.1.0
- Hadoop HDFS 3.3.6 (DataNode)
- AWS CLI v2
- Scripts de sync con S3

**Uso**:
```bash
# SSH a Storage
ssh -i ~/.ssh/bigd-key.pem ec2-user@<STORAGE_PUBLIC_IP>

# Copiar scripts
scp -i ~/.ssh/bigd-key.pem common-setup.sh setup-storage.sh ec2-user@<STORAGE_IP>:~

# Ejecutar
bash common-setup.sh
bash setup-storage.sh
```

---

## Flujo Completo de Deployment

### Paso 1: Crear Cluster

```bash
# En tu máquina local
cd bigdata-pipeline/infrastructure/scripts

# Ejecutar
chmod +x create-cluster.sh
./create-cluster.sh

# Guardar las IPs que se muestran
```

### Paso 2: Configurar /etc/hosts

```bash
# SSH a cada instancia y ejecutar:
# (usa las IPs de cluster-info.txt)

ssh -i ~/.ssh/bigd-key.pem ec2-user@<INSTANCE_PUBLIC_IP>

sudo tee -a /etc/hosts <<EOF
<MASTER_PRIVATE_IP>  master-node bigdata-master
<WORKER1_PRIVATE_IP> worker1-node bigdata-worker1
<WORKER2_PRIVATE_IP> worker2-node bigdata-worker2
<STORAGE_PRIVATE_IP> storage-node bigdata-storage
EOF

exit
```

Repetir para las 4 instancias.

### Paso 3: Actualizar orchestrate-cluster.sh

```bash
# En tu máquina local
vim orchestrate-cluster.sh

# Actualizar IPs (copiar desde cluster-info.txt)
MASTER_IP="<MASTER_PRIVATE_IP>"
WORKER1_IP="<WORKER1_PRIVATE_IP>"
WORKER2_IP="<WORKER2_PRIVATE_IP>"
STORAGE_IP="<STORAGE_PRIVATE_IP>"
SSH_KEY="~/.ssh/bigd-key.pem"
```

### Paso 4: Instalar Software

```bash
# Verificar conectividad
./orchestrate-cluster.sh test-connectivity

# Instalar todo (30-45 minutos)
./orchestrate-cluster.sh setup-all
```

### Paso 5: Iniciar Cluster

```bash
# Iniciar servicios
./orchestrate-cluster.sh start-cluster

# Verificar estado
./orchestrate-cluster.sh status
```

---

## Troubleshooting

### Error: Key pair no existe

```bash
# Crear nueva key
aws ec2 create-key-pair \
    --key-name bigd-key \
    --query 'KeyMaterial' \
    --output text > ~/.ssh/bigd-key.pem

chmod 400 ~/.ssh/bigd-key.pem
```

### Error: Security Group ya existe

El script detecta automáticamente y pregunta si quieres eliminarlo.

### Error: Permission denied (SSH)

```bash
# Verificar permisos de la key
chmod 400 ~/.ssh/bigd-key.pem

# Verificar que estás usando la IP pública
ssh -i ~/.ssh/bigd-key.pem ec2-user@<PUBLIC_IP>
```

### Ver logs de instalación

```bash
# Durante setup-all, los logs se muestran en tiempo real
# Si algo falla, SSH a la instancia específica

ssh -i ~/.ssh/bigd-key.pem ec2-user@<INSTANCE_IP>

# Ver logs
sudo journalctl -xe
tail -f /var/log/messages
```

---

## Security Group - Puertos Configurados

| Puerto(s) | Protocolo | Origen | Servicio |
|-----------|-----------|--------|----------|
| 22 | TCP | Tu IP | SSH |
| 2181 | TCP | VPC | Zookeeper |
| 5432 | TCP | VPC | PostgreSQL |
| 6123 | TCP | VPC | Flink RPC |
| 7077 | TCP | VPC | Spark Master |
| 8080-8088 | TCP | 0.0.0.0/0 | Web UIs |
| 9000 | TCP | VPC | HDFS NameNode |
| 9092 | TCP | VPC | Kafka |
| 9870 | TCP | 0.0.0.0/0 | HDFS Web UI |
| All | All | Security Group | Inter-cluster |

---

## Costos Estimados

| Componente | Costo |
|------------|-------|
| 1x t3.large | $0.0832/hora |
| 2x t3.xlarge | $0.3328/hora |
| EBS 550 GB | ~$0.036/hora |
| **Total** | **~$0.50/hora** |

**Con $50**: ~100 horas de operación

**Estrategia**: Apagar instancias cuando no se usen.

---

## Referencias

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
- [Plan de Arquitectura](../../docs/guides/PLAN_ARQUITECTURA.md)
- [Guía de Deployment](../../docs/DEPLOYMENT_GUIDE.md)
