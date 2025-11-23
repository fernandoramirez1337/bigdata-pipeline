# HDFS NameNode Binding Issue - TRUE ROOT CAUSE

## Critical Discovery

After running diagnostics, we discovered the **TRUE ROOT CAUSE** of DataNode connection failures:

**NameNode is listening on 127.0.0.1:9000 (localhost only), not on 0.0.0.0:9000 or the private IP!**

### Evidence

```bash
# From Master node netstat output:
tcp        0      0 127.0.0.1:9000          0.0.0.0:*               LISTEN      43569/java
                  ^^^^^^^^^^^
                  Localhost only!
```

### The Problem

- **NameNode configuration**: Listening on `127.0.0.1:9000` (localhost only)
- **DataNodes trying to connect to**: `172.31.72.49:9000` (private IP)
- **Result**: Connection refused - the NameNode is not accepting connections from other hosts!

This is **NOT** an AWS Security Group issue (though that might also need fixing later). This is a **Hadoop configuration issue**.

### Why This Happened

By default, or due to our configuration, Hadoop NameNode bound only to the loopback interface (localhost). The `fs.defaultFS` setting in `core-site.xml` specifies WHERE DataNodes should connect (`hdfs://172.31.72.49:9000`), but it doesn't control WHERE NameNode listens.

To control where NameNode listens, we need to set `dfs.namenode.rpc-bind-host` in `hdfs-site.xml`.

## Solution

### Quick Fix

Run the automated fix script:

```bash
chmod +x infrastructure/scripts/fix-namenode-binding.sh
./infrastructure/scripts/fix-namenode-binding.sh
```

This script will:
1. ✅ Add `dfs.namenode.rpc-bind-host = 0.0.0.0` to hdfs-site.xml
2. ✅ Add `dfs.namenode.servicerpc-bind-host = 0.0.0.0`
3. ✅ Add `dfs.namenode.http-bind-host = 0.0.0.0`
4. ✅ Restart NameNode
5. ✅ Verify NameNode is now listening on 0.0.0.0:9000
6. ✅ Test connectivity from all DataNodes
7. ✅ Restart DataNodes if connectivity succeeds
8. ✅ Show final HDFS cluster report

### Manual Fix

If you prefer to fix manually:

**1. SSH to Master node:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
```

**2. Edit hdfs-site.xml:**
```bash
sudo vi /opt/bigdata/hadoop/etc/hadoop/hdfs-site.xml
```

**3. Add these properties before `</configuration>`:**
```xml
    <property>
        <name>dfs.namenode.rpc-bind-host</name>
        <value>0.0.0.0</value>
        <description>NameNode RPC server will bind to this address</description>
    </property>

    <property>
        <name>dfs.namenode.servicerpc-bind-host</name>
        <value>0.0.0.0</value>
        <description>NameNode service RPC server will bind to this address</description>
    </property>

    <property>
        <name>dfs.namenode.http-bind-host</name>
        <value>0.0.0.0</value>
        <description>NameNode HTTP server will bind to this address</description>
    </property>
```

**4. Restart NameNode:**
```bash
source /etc/profile.d/bigdata.sh
$HADOOP_HOME/bin/hdfs --daemon stop namenode
sleep 3
$HADOOP_HOME/bin/hdfs --daemon start namenode
```

**5. Verify NameNode is listening on all interfaces:**
```bash
sudo netstat -tulnp | grep 9000
```

You should now see:
```
tcp        0      0 0.0.0.0:9000            0.0.0.0:*               LISTEN      <PID>/java
```

**6. Test connectivity from Worker1:**
```bash
# From your local machine:
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.221.77.132
timeout 3 bash -c 'cat < /dev/null > /dev/tcp/172.31.72.49/9000' && echo "✅ Connected!" || echo "❌ Still blocked"
```

**7. If connectivity works, restart all DataNodes:**
```bash
# Worker1
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.221.77.132 'source /etc/profile.d/bigdata.sh && $HADOOP_HOME/bin/hdfs --daemon stop datanode && sleep 3 && $HADOOP_HOME/bin/hdfs --daemon start datanode'

# Worker2
ssh -i ~/.ssh/bigd-key.pem ec2-user@3.219.215.11 'source /etc/profile.d/bigdata.sh && $HADOOP_HOME/bin/hdfs --daemon stop datanode && sleep 3 && $HADOOP_HOME/bin/hdfs --daemon start datanode'

# Storage
ssh -i ~/.ssh/bigd-key.pem ec2-user@98.88.249.180 'source /etc/profile.d/bigdata.sh && $HADOOP_HOME/bin/hdfs --daemon stop datanode && sleep 3 && $HADOOP_HOME/bin/hdfs --daemon start datanode'
```

**8. Wait 30 seconds, then check HDFS report:**
```bash
ssh -i ~/.ssh/bigd-key.pem ec2-user@44.210.18.254
source /etc/profile.d/bigdata.sh
hdfs dfsadmin -report
```

## Expected Result

After the fix, you should see:

### Correct Port Binding:
```
tcp        0      0 0.0.0.0:9000            0.0.0.0:*               LISTEN      <PID>/java
```
Not `127.0.0.1:9000`!

### Successful HDFS Cluster:
```
Configured Capacity: 558345948160 (520 GB)
Live datanodes (3):

Name: 172.31.15.51:9866 (worker1-node)
Configured Capacity: 171798691840 (160 GB)
...

Name: 172.31.7.120:9866 (worker2-node)
Configured Capacity: 171798691840 (160 GB)
...

Name: 172.31.11.89:9866 (storage-node)
Configured Capacity: 214748364800 (200 GB)
...
```

## What About AWS Security Groups?

After fixing the NameNode binding:
- **If DataNodes connect successfully**: AWS Security Groups are already configured correctly
- **If DataNodes still can't connect**: Then we need to add AWS Security Group rules (see `AWS_SECURITY_GROUP_FIX.md`)

Most likely, the Security Groups are fine, and this binding issue was the only problem.

## Technical Explanation

### Hadoop Configuration Hierarchy

Hadoop has several levels of network configuration:

1. **fs.defaultFS** (in core-site.xml): Tells clients WHERE to connect
   - Example: `hdfs://172.31.72.49:9000`
   - This is the "advertisement" address

2. **dfs.namenode.rpc-bind-host** (in hdfs-site.xml): Tells NameNode WHERE to listen
   - Default: `0.0.0.0` (but can be overridden by other settings)
   - If not set or incorrectly configured, may bind to localhost only

3. **Network binding priority**:
   - If `dfs.namenode.rpc-bind-host` is set → Use that
   - Else if `dfs.namenode.rpc-address` includes a specific IP → May bind to that or localhost
   - Else → May default to localhost (127.0.0.1)

### Why 0.0.0.0 is the Solution

- `0.0.0.0` means "listen on ALL network interfaces"
- This allows connections from:
  - Localhost (127.0.0.1)
  - Private IP (172.31.72.49)
  - Any other network interface

### Security Considerations

**Is binding to 0.0.0.0 safe?**

Yes, in this context:
- EC2 instances are in a VPC with Security Groups as the firewall
- Security Groups control which external IPs can connect
- Binding to 0.0.0.0 just means "accept connections that reach this host"
- AWS Security Groups still control WHO can reach the host

**Alternative: Bind to specific private IP**

If you prefer more restrictive binding:
```xml
<property>
    <name>dfs.namenode.rpc-bind-host</name>
    <value>172.31.72.49</value>
</property>
```

But `0.0.0.0` is standard practice and recommended for cluster deployments.

## Debugging History

This issue was tricky to diagnose because:

1. ✅ NameNode process was running
2. ✅ NameNode logs showed no errors
3. ✅ Configuration files looked correct (`fs.defaultFS = hdfs://172.31.72.49:9000`)
4. ✅ DataNode processes were running
5. ❌ DataNodes couldn't connect

Initial hypothesis was AWS Security Groups, but the `netstat` output revealed the true issue:
```
tcp  0  0  127.0.0.1:9000  0.0.0.0:*  LISTEN  43569/java
           ^^^^^^^^^^^
           The smoking gun!
```

## Lessons Learned

1. **Always check actual port bindings** with `netstat -tulnp` or `ss -tulnp`
2. **Don't assume** that `fs.defaultFS` controls WHERE NameNode listens
3. **Hadoop's default behavior** can vary based on system hostname resolution
4. **Network debugging** requires checking both:
   - Configuration (what we THINK is happening)
   - Actual bindings (what is ACTUALLY happening)

## Related Configuration Files

- `infrastructure/scripts/setup-master.sh` - Initial Hadoop configuration (needs to be updated to include bind-host settings)
- `/opt/bigdata/hadoop/etc/hadoop/core-site.xml` - Sets fs.defaultFS
- `/opt/bigdata/hadoop/etc/hadoop/hdfs-site.xml` - Should set dfs.namenode.rpc-bind-host

## Next Steps After Fix

Once DataNodes are connected:
1. ✅ Create HDFS directories: `/user`, `/data`, `/tmp`
2. ✅ Set proper permissions
3. ✅ Test file upload/download
4. ✅ Deploy data processing jobs
5. ✅ Monitor HDFS health at http://44.210.18.254:9870

---

**Date**: November 20, 2025
**Issue**: DataNodes cannot connect to NameNode
**Root Cause**: NameNode binding to localhost only (127.0.0.1:9000)
**Solution**: Configure dfs.namenode.rpc-bind-host = 0.0.0.0
**Status**: ⏳ Fix script created, awaiting execution
