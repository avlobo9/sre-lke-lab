# 07 — Persistent Volumes on LKE

This section demonstrates persistent storage on LKE using the Linode Block Storage CSI driver. Understanding how Kubernetes integrates with cloud provider storage is essential for an LKE SRE because storage issues are one of the most common causes of production incidents.

---

## Why This Matters For The LKE SRE Role

LKE ships with the Linode Block Storage CSI driver pre-installed. When a customer creates a PersistentVolumeClaim, the CSI driver automatically provisions a Linode block storage volume and attaches it to the node. As an SRE you need to understand this entire flow so you can debug PVC binding failures, volume attachment issues, and storage class misconfigurations.

---

## How Storage Works On LKE

```
PVC created  →  StorageClass selected  →  CSI driver called
                                               ↓
                                    Linode Block Storage API
                                               ↓
                                    Volume created in Linode
                                               ↓
                                    Volume attached to node
                                               ↓
                                    Mounted into pod at mountPath
```

---

## Step By Step Instructions

### Step 1 — Check The Pre-Installed Storage Class

```bash
# LKE comes with a default StorageClass for Linode Block Storage
kubectl get storageclass
kubectl describe storageclass linode-block-storage-retain

# Note the two storage classes on LKE:
# linode-block-storage        — deletes the volume when PVC is deleted
# linode-block-storage-retain — keeps the volume when PVC is deleted
#
# Use 'retain' for production data you cannot afford to lose
```

### Step 2 — Check The CSI Driver Is Running

```bash
# The CSI driver runs as pods in the kube-system namespace
kubectl get pods -n kube-system | grep csi

# You should see:
# csi-linode-controller-*  — handles volume provisioning and attachment
# csi-linode-node-*        — handles volume mounting on each node

# Check CSI driver logs if you have storage issues
kubectl logs -n kube-system -l app=csi-linode-controller
```

### Step 3 — Create A PersistentVolumeClaim

```bash
kubectl apply -f pvc-example.yaml

# Watch the PVC — it will go from Pending to Bound
kubectl get pvc -n production -w

# When Bound, a Linode block storage volume has been created
# You can verify in the Linode Cloud Manager under Volumes

# Describe the PVC to see which PV was created
kubectl describe pvc production-data -n production
```

### Step 4 — Deploy A Pod That Uses The PVC

```bash
kubectl apply -f pod-with-pvc.yaml

# Wait for the pod to start
kubectl get pod storage-demo -n production -w

# Verify the volume is mounted
kubectl exec -n production storage-demo -- df -h /data
kubectl exec -n production storage-demo -- ls /data
```

### Step 5 — Write Data And Verify Persistence

```bash
# Write data to the persistent volume
kubectl exec -n production storage-demo -- \
  sh -c 'echo "persistent data test $(date)" > /data/test.txt'

# Read it back
kubectl exec -n production storage-demo -- cat /data/test.txt

# Delete the pod
kubectl delete pod storage-demo -n production

# Recreate the pod
kubectl apply -f pod-with-pvc.yaml

# Wait for it to start
kubectl get pod storage-demo -n production -w

# Verify the data is still there after pod recreation
kubectl exec -n production storage-demo -- cat /data/test.txt
# The data should still be there — this is what persistence means
```

### Step 6 — Deploy A StatefulSet With Persistent Storage

```bash
kubectl apply -f statefulset-with-storage.yaml

# Each pod gets its own PVC — this is the key advantage of StatefulSets
kubectl get pvc -n production
kubectl get pods -n production -l app=stateful-app

# Each pod has a stable identity
# stateful-app-0, stateful-app-1, stateful-app-2
# Each has its own volume: data-stateful-app-0, data-stateful-app-1, etc.
```

### Step 7 — Simulate A Volume Attachment Issue And Debug It

```bash
# Delete a pod that has a PVC — the volume must detach before reattaching
kubectl delete pod storage-demo -n production

# Watch what happens — sometimes the volume gets stuck detaching
kubectl get pvc -n production -w
kubectl describe pvc production-data -n production

# If the volume is stuck, check the CSI controller logs
kubectl logs -n kube-system -l app=csi-linode-controller --tail=50

# Check node events for attachment issues
kubectl get events -n production --sort-by=.lastTimestamp
```

### Step 8 — Clean Up

```bash
# IMPORTANT: Deleting a PVC with the default storage class DELETES the Linode volume
# Use linode-block-storage-retain if you want the volume to survive PVC deletion

kubectl delete -f pod-with-pvc.yaml
kubectl delete -f pvc-example.yaml
kubectl delete -f statefulset-with-storage.yaml

# PVCs created by StatefulSet volumeClaimTemplates must be deleted manually
kubectl delete pvc -n production -l app=stateful-app
```

---

## Common Storage Issues And How To Debug Them

```
Issue                     Symptom                    Debug Command
PVC stuck in Pending      Pod won't start            kubectl describe pvc <name>
Volume quota exceeded     PVC stays Pending          Check Linode account limits
Wrong storage class       PVC bound but wrong size   kubectl get pvc -o yaml
Volume stuck detaching    New pod won't start        kubectl logs -n kube-system csi-controller
Node full                 Pod evicted                kubectl describe node <name>
```

---

## Interview Talking Points

> **Q: How does persistent storage work on managed Kubernetes platforms like LKE?**

> *"On LKE, Linode ships a CSI driver pre-installed that integrates with the Linode Block Storage API. When a PVC is created, the CSI controller pod calls the Linode API to provision a block storage volume, then the CSI node plugin handles mounting it into the pod. LKE provides two storage classes — one that deletes the volume when the PVC is deleted, and a retain variant that keeps the volume. In production I always use the retain class so data is not accidentally lost if a PVC is deleted. For stateful workloads like databases I use StatefulSets with volumeClaimTemplates so each pod gets its own dedicated volume with a stable identity. Common issues I have debugged include PVCs stuck in Pending due to capacity quota limits, volumes stuck in the detaching state when a pod is deleted on an unresponsive node, and storage class misconfiguration causing volumes to be provisioned in the wrong region."*
