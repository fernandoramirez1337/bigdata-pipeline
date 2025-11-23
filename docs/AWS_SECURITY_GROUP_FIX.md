# AWS Security Group Fix for HDFS DataNode Connection Issue

## Problem Summary

**Symptom**: DataNodes are running as processes but showing "0 B capacity" in HDFS cluster report. No live DataNodes registered with NameNode.

**Root Cause**: AWS Security Groups are blocking port 9000 (HDFS NameNode RPC) between EC2 instances.

**Evidence**:
- DataNode processes running on all worker nodes ✅
- DataNode logs show: `Retrying connect to server: master-node/172.31.72.49:9000`
- Network connectivity test: `Connection refused` when trying to reach port 9000
- HDFS report: `Configured Capacity: 0 (0 B)`, `Live datanodes (0)`

## Solution: Add AWS Security Group Inbound Rules

### Step-by-Step Instructions

#### 1. Access AWS Console
Go to: https://console.aws.amazon.com/ec2/

#### 2. Navigate to Security Groups
- In the left sidebar, click **Network & Security** → **Security Groups**
- Find the security group(s) attached to your EC2 instances
  - You can check which security group is attached by going to **EC2 Instances** and viewing the instance details

#### 3. Edit Inbound Rules
Click on the security group, then click **"Edit inbound rules"**

#### 4. Add Three New Rules

**Rule 1: HDFS NameNode RPC**
```
Type: Custom TCP
Port range: 9000
Source: Custom → [Select your security group ID]
       OR
       Custom → 172.31.0.0/16
Description: HDFS NameNode RPC
```

**Rule 2: HDFS DataNode Data Transfer**
```
Type: Custom TCP
Port range: 9866
Source: Custom → [Select your security group ID]
       OR
       Custom → 172.31.0.0/16
Description: HDFS DataNode data transfer
```

**Rule 3: HDFS DataNode IPC**
```
Type: Custom TCP
Port range: 9867
Source: Custom → [Select your security group ID]
       OR
       Custom → 172.31.0.0/16
Description: HDFS DataNode IPC
```

#### 5. Save Rules
Click **"Save rules"** at the bottom of the page

#### 6. Wait for Propagation
Wait 1-2 minutes for the security group rules to propagate across AWS infrastructure

#### 7. Verify and Restart
Run the automated fix script:
```bash
chmod +x infrastructure/scripts/complete-cluster-fix.sh
./infrastructure/scripts/complete-cluster-fix.sh
```

This script will:
- ✅ Verify NameNode is listening on port 9000
- ✅ Test network connectivity from all DataNodes
- ✅ Provide AWS Security Group instructions (if needed)
- ✅ Restart DataNodes after you've added the rules
- ✅ Show final HDFS cluster report with all 3 live DataNodes

## Expected Result

After adding the security group rules and restarting DataNodes, you should see:

```
Live datanodes (3):

Name: 172.31.15.51:9866 (worker1-node)
Configured Capacity: 171798691840 (160 GB)
DFS Used: 24576 (24 KB)
...

Name: 172.31.7.120:9866 (worker2-node)
Configured Capacity: 171798691840 (160 GB)
DFS Used: 24576 (24 KB)
...

Name: 172.31.11.89:9866 (storage-node)
Configured Capacity: 214748364800 (200 GB)
DFS Used: 24576 (24 KB)
...
```

## Alternative: Using AWS CLI

If you prefer using AWS CLI instead of the web console:

```bash
# Get your security group ID
aws ec2 describe-instances --instance-ids i-YOUR-INSTANCE-ID \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text

# Add the three inbound rules
aws ec2 authorize-security-group-ingress \
  --group-id sg-YOUR-SECURITY-GROUP-ID \
  --ip-permissions \
    IpProtocol=tcp,FromPort=9000,ToPort=9000,IpRanges='[{CidrIp=172.31.0.0/16,Description="HDFS NameNode RPC"}]' \
    IpProtocol=tcp,FromPort=9866,ToPort=9866,IpRanges='[{CidrIp=172.31.0.0/16,Description="HDFS DataNode data transfer"}]' \
    IpProtocol=tcp,FromPort=9867,ToPort=9867,IpRanges='[{CidrIp=172.31.0.0/16,Description="HDFS DataNode IPC"}]'
```

## Troubleshooting

### If DataNodes still don't connect after adding rules:

1. **Verify rules were added correctly**:
   - Check that the source is either your security group ID or `172.31.0.0/16`
   - Ensure all three ports (9000, 9866, 9867) are added
   - Verify the security group is actually attached to all your EC2 instances

2. **Check NameNode is listening**:
   ```bash
   ./infrastructure/scripts/check-namenode-port.sh
   ```

3. **Test connectivity manually**:
   ```bash
   ./infrastructure/scripts/verify-ports-and-restart.sh
   ```

4. **Check DataNode logs**:
   ```bash
   ./infrastructure/scripts/deep-debug-datanodes.sh
   ```

   Look for:
   - `Connection refused` → Security group issue
   - `No route to host` → Network routing issue
   - `Successfully registered` → Success!

## Why This Happened

AWS Security Groups act as virtual firewalls for EC2 instances. By default, they block all inbound traffic unless explicitly allowed. When we set up the cluster, we likely only opened ports for:
- SSH (22)
- Web UIs (8080, 8081, 9870, etc.)

We didn't open the **internal communication ports** that Hadoop services need to talk to each other:
- Port 9000: NameNode RPC (DataNodes register here)
- Port 9866: DataNode-to-DataNode data transfer
- Port 9867: DataNode IPC

## Security Note

Using `172.31.0.0/16` as the source allows all instances in the default VPC to communicate. This is safe for:
- Development/testing environments
- Private VPCs

For production, you might want to:
- Use security group references (select the same security group as source)
- Create separate security groups for each service tier
- Use more restrictive CIDR blocks if instances are in different subnets

## Complete Port Reference for Big Data Cluster

For reference, here are all the ports used by the cluster:

### External Access (from your laptop):
- 22 (SSH) - Already configured
- 9870 (HDFS NameNode Web UI) - Already configured
- 8080 (Spark Master Web UI) - Already configured
- 8081 (Flink Dashboard) - Already configured
- 8088 (Superset) - Already configured

### Internal Communication (between EC2 instances):
- **9000** (HDFS NameNode RPC) ← **MISSING** (causes DataNode connection failure)
- **9866** (HDFS DataNode data transfer) ← **MISSING**
- **9867** (HDFS DataNode IPC) ← **MISSING**
- 2181 (Zookeeper)
- 9092 (Kafka)
- 7077 (Spark Master RPC)
- 6123 (Flink JobManager RPC)

The first three (9000, 9866, 9867) are critical for HDFS operation and must be added to your security group.
