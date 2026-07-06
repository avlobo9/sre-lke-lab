# 05 — etcd Operations

This section covers etcd operations in the context of a managed Kubernetes cluster like LKE. Even though Linode manages the etcd control plane for you, understanding etcd deeply is essential for a Senior SRE interview on the LKE team — because YOU are the person who has to explain etcd behaviour to customers and debug control plane performance issues.

---

## Why This Matters For The LKE SRE Role

The LKE JD specifically calls out `etcd` as a control plane component you must have expert hands-on experience with. On the LKE team you will:
- Monitor etcd health and latency metrics via Prometheus
- Investigate API server slowness caused by etcd performance degradation
- Guide customers through etcd-related cluster recovery scenarios
- Understand what happens to the cluster when etcd loses quorum

---

## What Is etcd

```
etcd is the distributed key-value store that holds ALL cluster state.
Every object in Kubernetes — pods, deployments, configmaps, secrets,
service accounts, RBAC rules — is stored as a key-value entry in etcd.

If etcd is lost and there is no backup:
  → The cluster is unrecoverable
  → All workloads continue running (kubelet is independent)
  → But the API server cannot function
  → kubectl stops working entirely
  → No new pods can be scheduled
  → No services can be updated
```

---

## etcd Architecture On Managed vs Self-Hosted K8s

```
Self-hosted K8s              Managed K8s (LKE)

You manage etcd:             Linode manages etcd:
- Installation               - You cannot SSH to control plane
- TLS certificates           - You cannot run etcdctl directly
- Backup and restore         - But you CAN:
- Defrag operations            - Monitor via Prometheus metrics
- Quorum management            - Check health via API server
- Version upgrades             - Use Velero for resource backup
                               - Use LKE snapshots
```

---

## Step By Step Instructions

### Step 1 — Check etcd Health Via The API Server

On managed LKE you check etcd health indirectly through the API server:

```bash
# Check component statuses
kubectl get componentstatuses

# Check API server health (which depends on etcd)
kubectl get --raw /healthz
kubectl get --raw /healthz/etcd

# Check if the API server can reach etcd
kubectl get --raw /readyz
```

Expected output from `/healthz/etcd`:
```
ok
```

If you see anything other than `ok`, etcd has an issue.

### Step 2 — Monitor etcd Metrics Via Prometheus

The API server exposes etcd metrics via its own metrics endpoint. After deploying the Prometheus stack from section 02, run these queries:

```promql
# etcd request latency (99th percentile) — should be under 100ms
histogram_quantile(0.99, rate(etcd_request_duration_seconds_bucket[5m]))

# etcd database size — alert if approaching 2GB (default quota)
etcd_mvcc_db_total_size_in_bytes

# etcd leader changes — frequent changes indicate instability
rate(etcd_server_leader_changes_seen_total[1h])

# Number of failed proposals — should be near 0
rate(etcd_server_proposals_failed_total[5m])

# etcd keys total
etcd_debugging_mvcc_keys_total

# Compaction frequency
rate(etcd_mvcc_db_compaction_total[1h])
```

### Step 3 — Run The Backup Script

Review `etcd-backup.sh` and understand each command before running it.

For self-hosted clusters:
```bash
chmod +x etcd-backup.sh
./etcd-backup.sh
```

For LKE (managed), use the resource-level backup approach:
```bash
# Install Velero for Kubernetes resource backup
# Velero backs up K8s resource definitions to object storage
# This is the recommended approach for managed K8s
velero backup create cluster-backup-$(date +%Y%m%d) \
  --include-namespaces='*' \
  --wait

# List backups
velero backup get

# Describe a backup
velero backup describe cluster-backup-$(date +%Y%m%d)
```

### Step 4 — Understand etcd Defragmentation

etcd does not immediately reclaim disk space when keys are deleted. Defragmentation compacts the database and reclaims space. On self-hosted clusters:

```bash
# Check current db size before defrag
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  endpoint status --write-out=table

# Run defrag
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  defrag

# Verify size reduced after defrag
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/healthcheck-client.crt \
  --key=/etc/kubernetes/pki/etcd/healthcheck-client.key \
  endpoint status --write-out=table
```

### Step 5 — Understand etcd Quorum

```
etcd uses the Raft consensus algorithm.
Quorum = (n/2) + 1 members must agree before a write is committed.

Cluster size    Quorum needed    Can tolerate losing
1 member        1                0 members
3 members       2                1 member
5 members       3                2 members
7 members       4                3 members

LKE uses a 3-member etcd cluster behind the scenes.
This means it can tolerate losing 1 etcd member before the
cluster becomes read-only and kubectl stops working.
```

### Step 6 — Simulate What Happens When etcd Is Slow

```bash
# Generate a large number of objects to stress etcd
for i in $(seq 1 100); do
  kubectl create configmap stress-test-$i \
    --from-literal=key=value \
    --namespace=default
done

# Check API server latency
kubectl get --raw /metrics | grep apiserver_request_duration

# Clean up
for i in $(seq 1 100); do
  kubectl delete configmap stress-test-$i --namespace=default
done

# After deleting many objects, etcd database size does not shrink
# This is when defragmentation is needed
# Monitor: etcd_mvcc_db_total_size_in_bytes before and after cleanup
```

---

## Key etcd Facts For Interviews

```
Default storage quota     →  2GB (etcd stops accepting writes if exceeded)
Max recommended DB size   →  8GB with custom quota
Default compaction        →  Every 5 minutes in newer versions
Backup frequency          →  Before every cluster upgrade, daily in production
Restore impact            →  Restores to a point in time — objects created
                             after the backup are lost
Quorum loss               →  Cluster becomes read-only — workloads keep
                             running but nothing can be changed
```

---

## Interview Talking Points

> **Q: Tell me about your experience with etcd.**

> *"etcd is the heart of any Kubernetes cluster — it stores all cluster state as key-value pairs, and if it goes down the API server stops functioning even though running workloads continue. On managed clusters like LKE I monitor etcd health indirectly through the API server health endpoints and through Prometheus metrics including request latency, database size, leader change rate, and failed proposal rate. I alert on etcd database size approaching the 2GB default quota and on elevated leader change rates which indicate network instability between etcd members. For backup I use Velero on managed clusters for resource-level backup, and I understand that on self-hosted clusters you use etcdctl snapshot save and snapshot restore. I also understand etcd compaction and defragmentation — etcd does not reclaim disk space automatically when keys are deleted, so regular defrag is needed to prevent the database from hitting the storage quota."*
