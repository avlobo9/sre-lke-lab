#!/bin/bash
# etcd-backup.sh
# Backs up etcd snapshot to a local file and optionally uploads to object storage
#
# IMPORTANT: This script is designed for SELF-HOSTED Kubernetes clusters
# where you have direct access to the etcd endpoint and certificates.
# For MANAGED clusters like LKE, use Velero (see README.md Step 3).
#
# Usage: ./etcd-backup.sh
# Prerequisites: etcdctl installed, access to etcd certificates

set -euo pipefail

# --- Configuration ---
# etcd endpoint — for kubeadm clusters this is usually localhost:2379
ETCD_ENDPOINT="https://127.0.0.1:2379"

# Paths to etcd TLS certificates
# For kubeadm clusters these are in /etc/kubernetes/pki/etcd/
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/healthcheck-client.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/healthcheck-client.key"

# Backup destination
BACKUP_DIR="/var/backups/etcd"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/etcd-snapshot-${TIMESTAMP}.db"

# How many backups to keep locally
RETENTION_COUNT=7

# --- Helper functions ---
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_prerequisites() {
  # Verify etcdctl is installed
  if ! command -v etcdctl &> /dev/null; then
    log "ERROR: etcdctl is not installed. Install with: brew install etcd"
    exit 1
  fi

  # Verify certificate files exist
  for file in "$ETCD_CACERT" "$ETCD_CERT" "$ETCD_KEY"; do
    if [ ! -f "$file" ]; then
      log "ERROR: Certificate file not found: $file"
      exit 1
    fi
  done

  # Create backup directory if it does not exist
  mkdir -p "$BACKUP_DIR"
  log "Backup directory: $BACKUP_DIR"
}

check_etcd_health() {
  log "Checking etcd cluster health..."

  # Check endpoint health before taking a backup
  ETCDCTL_API=3 etcdctl \
    --endpoints="$ETCD_ENDPOINT" \
    --cacert="$ETCD_CACERT" \
    --cert="$ETCD_CERT" \
    --key="$ETCD_KEY" \
    endpoint health

  # Check endpoint status (shows DB size, leader, raft index)
  log "etcd endpoint status:"
  ETCDCTL_API=3 etcdctl \
    --endpoints="$ETCD_ENDPOINT" \
    --cacert="$ETCD_CACERT" \
    --cert="$ETCD_CERT" \
    --key="$ETCD_KEY" \
    endpoint status --write-out=table
}

take_snapshot() {
  log "Taking etcd snapshot..."

  # Save snapshot to file
  # This is a point-in-time consistent snapshot of the entire etcd database
  ETCDCTL_API=3 etcdctl \
    --endpoints="$ETCD_ENDPOINT" \
    --cacert="$ETCD_CACERT" \
    --cert="$ETCD_CERT" \
    --key="$ETCD_KEY" \
    snapshot save "$BACKUP_FILE"

  log "Snapshot saved to: $BACKUP_FILE"

  # Verify the snapshot is valid
  ETCDCTL_API=3 etcdctl snapshot status "$BACKUP_FILE" --write-out=table
  log "Snapshot verification complete"
}

rotate_old_backups() {
  log "Rotating old backups (keeping last $RETENTION_COUNT)..."

  # List backups sorted by date, remove oldest if over retention count
  local backup_count
  backup_count=$(ls -1 "${BACKUP_DIR}"/etcd-snapshot-*.db 2>/dev/null | wc -l)

  if [ "$backup_count" -gt "$RETENTION_COUNT" ]; then
    local to_delete=$(( backup_count - RETENTION_COUNT ))
    ls -1t "${BACKUP_DIR}"/etcd-snapshot-*.db | tail -n "$to_delete" | xargs rm -f
    log "Deleted $to_delete old backup(s)"
  else
    log "No rotation needed ($backup_count backups present)"
  fi
}

optional_upload_to_s3() {
  # Uncomment and configure this block to upload backups to S3-compatible storage
  # This works with AWS S3, Linode Object Storage, or any S3-compatible endpoint
  #
  # BUCKET="REPLACE_ME_BUCKET_NAME"
  # S3_ENDPOINT="https://us-east-1.linodeobjects.com"  # Linode Object Storage
  #
  # aws s3 cp "$BACKUP_FILE" "s3://${BUCKET}/etcd-backups/" \
  #   --endpoint-url "$S3_ENDPOINT"
  #
  # log "Uploaded backup to s3://${BUCKET}/etcd-backups/$(basename $BACKUP_FILE)"
  log "S3 upload is disabled. Configure optional_upload_to_s3() to enable."
}

restore_instructions() {
  # Print restore instructions for reference
  # NEVER run this block automatically — restore is a manual, deliberate operation
  cat <<EOF

--- HOW TO RESTORE FROM THIS BACKUP ---

WARNING: etcd restore is destructive. Only do this in a real emergency.
Always consult your team before restoring.

1. Stop the API server:
   mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/

2. Stop etcd:
   mv /etc/kubernetes/manifests/etcd.yaml /tmp/

3. Restore the snapshot:
   ETCDCTL_API=3 etcdctl snapshot restore $BACKUP_FILE \\
     --data-dir=/var/lib/etcd-restore \\
     --name=master \\
     --initial-cluster=master=https://127.0.0.1:2380 \\
     --initial-cluster-token=etcd-cluster-1 \\
     --initial-advertise-peer-urls=https://127.0.0.1:2380

4. Update etcd manifest to use the new data dir:
   Edit /tmp/etcd.yaml and change --data-dir to /var/lib/etcd-restore

5. Restore the manifests:
   mv /tmp/etcd.yaml /etc/kubernetes/manifests/
   mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/

6. Verify cluster is healthy:
   kubectl get nodes
   kubectl get pods --all-namespaces

Backup file used: $BACKUP_FILE
Backup timestamp: $TIMESTAMP
---
EOF
}

# --- Main execution ---
main() {
  log "=== etcd Backup Started ==="
  check_prerequisites
  check_etcd_health
  take_snapshot
  rotate_old_backups
  optional_upload_to_s3
  restore_instructions
  log "=== etcd Backup Completed: $BACKUP_FILE ==="
}

main "$@"
