# IP Management System

**Last Updated**: 2025-11-23

## Overview

The cluster uses a centralized IP management system where IPs are configured once and automatically used by all scripts.

## How It Works

### 1. Configure IPs (Once)

Use `quick-start.sh` to configure your cluster IPs:

```bash
./quick-start.sh
```

When prompted, enter your current EC2 instance IPs. The script will:
- ✅ Save IPs to `.cluster-ips` file
- ✅ Test SSH connectivity
- ✅ Start the cluster

### 2. IPs Persist Across Sessions

The `.cluster-ips` file stores:
```bash
MASTER_IP="44.221.82.82"
WORKER1_IP="3.236.229.102"
WORKER2_IP="13.222.123.53"
STORAGE_IP="3.91.82.140"
SSH_KEY="/Users/username/.ssh/bigd-key.pem"
SSH_USER="ec2-user"
```

### 3. Scripts Auto-Load IPs

All cluster management scripts automatically read from `.cluster-ips`:

- ✅ `verify-cluster-health.sh` - Uses saved IPs
- ✅ `cluster-dashboard.sh` - Uses saved IPs
- ✅ `start-cluster.sh` - Uses saved IPs
- ✅ Any other infrastructure scripts

## Quick Reference

### First Time Setup

```bash
# Run interactive setup (saves IPs)
./quick-start.sh
```

### Subsequent Startups

```bash
# Quick startup (uses saved IPs)
./quick-start.sh

# Or direct startup
./infrastructure/scripts/start-cluster.sh
```

### Verify Cluster Health

```bash
# Uses saved IPs automatically
./infrastructure/scripts/verify-cluster-health.sh
```

### View Dashboard

```bash
# Uses saved IPs automatically
./infrastructure/scripts/cluster-dashboard.sh
```

### Update IPs (When EC2 IPs Change)

Just run `quick-start.sh` again and enter new IPs when prompted:

```bash
./quick-start.sh
# Answer 'n' when asked "Are these IPs still correct?"
# Enter new IPs
# Script will update .cluster-ips automatically
```

## Manual IP Configuration

If you prefer to manually set IPs:

### Option 1: Edit .cluster-ips

```bash
vim .cluster-ips
# Update the IP values
# Save and exit
```

### Option 2: Environment Variables

```bash
export MASTER_IP="44.221.82.82"
export WORKER1_IP="3.236.229.102"
export WORKER2_IP="13.222.123.53"
export STORAGE_IP="3.91.82.140"

./infrastructure/scripts/start-cluster.sh
```

## File Structure

```
bigdata-pipeline/
├── .cluster-ips              # Auto-generated IP config (gitignored)
├── quick-start.sh            # Interactive setup (creates .cluster-ips)
└── infrastructure/scripts/
    ├── start-cluster.sh      # Reads .cluster-ips
    ├── verify-cluster-health.sh  # Reads .cluster-ips
    └── cluster-dashboard.sh  # Reads .cluster-ips
```

## Troubleshooting

### IPs Not Loading

If scripts aren't finding your IPs:

1. **Check .cluster-ips exists**:
   ```bash
   ls -la .cluster-ips
   ```

2. **Verify .cluster-ips content**:
   ```bash
   cat .cluster-ips
   ```

3. **Re-run quick-start.sh**:
   ```bash
   ./quick-start.sh
   ```

### Wrong IPs

```bash
# Just run quick-start.sh again
./quick-start.sh
# Answer 'n' and enter correct IPs
```

## Benefits

- ✅ **Configure once, use everywhere** - Set IPs in one place
- ✅ **Automatic persistence** - IPs saved across sessions
- ✅ **No hardcoding** - All scripts read from same source
- ✅ **Easy updates** - Re-run quick-start.sh to update
- ✅ **Fallback defaults** - Scripts have backup IPs if file missing

## Best Practices

1. **Always use quick-start.sh first** when working with a new cluster
2. **Keep .cluster-ips local** (it's gitignored) - IPs are instance-specific
3. **Re-run quick-start.sh** whenever your EC2 IPs change
4. **Verify after changes** - Run `verify-cluster-health.sh` after updating IPs

---

**See Also:**
- [README.md](README.md) - Main project documentation
- [QUICK_START.md](QUICK_START.md) - Quick start guide
- [CLAUDE.md](CLAUDE.md) - AI assistant guide
