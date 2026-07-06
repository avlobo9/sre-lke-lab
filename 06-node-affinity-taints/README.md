# 06 — Node Affinity, Taints, Tolerations, PDBs, and Priority Classes

This section covers production workload placement patterns. These are the controls that determine WHERE pods run, HOW they survive node failures, and WHICH pods get resources first when the cluster is under pressure.

---

## Why This Matters For The LKE SRE Role

On LKE, customers run mixed workloads — stateful databases, stateless APIs, batch jobs, and critical system components — all on the same cluster. As an SRE you need to design and debug workload placement so that critical workloads survive node failures and noisy neighbours do not starve each other.

---

## Concepts Overview

```
Node Affinity        →  Pull pods TOWARD specific nodes (preference or requirement)
Taints               →  Push pods AWAY from nodes (node repels pods)
Tolerations          →  Allow pods to IGNORE a taint (pod accepts the node)
Pod Disruption Budget→  Guarantee minimum replicas during voluntary disruptions
Priority Class       →  Define which pods get evicted LAST when resources are scarce
```

---

## Step By Step Instructions

### Step 1 — Label Your Nodes

Node affinity works by matching pod requirements to node labels. First label your nodes:

```bash
# View current node labels
kubectl get nodes --show-labels

# Get node names
kubectl get nodes -o wide

# Label a node as a dedicated database node
kubectl label node <NODE_NAME_1> workload-type=database

# Label another node as an application node
kubectl label node <NODE_NAME_2> workload-type=application

# Verify labels were applied
kubectl get nodes --show-labels | grep workload-type
```

### Step 2 — Deploy Node Affinity Example

```bash
kubectl apply -f node-affinity-example.yaml

# Watch where the pod gets scheduled
kubectl get pod affinity-demo -o wide

# It should land on the node labelled workload-type=database
# Describe to see the affinity rules applied
kubectl describe pod affinity-demo
```

### Step 3 — Apply A Taint And Deploy With Toleration

```bash
# Taint a node — this repels all pods that do not tolerate the taint
kubectl taint node <NODE_NAME_1> dedicated=gpu:NoSchedule

# Verify the taint was applied
kubectl describe node <NODE_NAME_1> | grep Taints

# Try to deploy a pod WITHOUT a toleration — it should stay Pending
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-toleration-pod
spec:
  containers:
    - name: nginx
      image: nginx
      resources:
        limits:
          cpu: 100m
          memory: 128Mi
EOF

# Check it is Pending because the only available node has the taint
kubectl get pod no-toleration-pod
kubectl describe pod no-toleration-pod | grep -A5 Events

# Now deploy the pod WITH toleration
kubectl apply -f taints-tolerations-example.yaml

# This pod should schedule on the tainted node
kubectl get pod toleration-demo -o wide

# Clean up
kubectl delete pod no-toleration-pod

# Remove the taint when done
kubectl taint node <NODE_NAME_1> dedicated=gpu:NoSchedule-
```

### Step 4 — Deploy Pod Disruption Budget

```bash
kubectl apply -f pod-disruption-budget.yaml

# Verify the PDB was created
kubectl get pdb -n production
kubectl describe pdb production-app-pdb -n production

# The PDB ensures that during node drain or cluster upgrade
# at least 2 replicas of the production-app are always running
# kubectl drain will respect this and wait if draining would violate it
```

### Step 5 — Deploy Priority Classes

```bash
kubectl apply -f priority-class.yaml

# Verify priority classes exist
kubectl get priorityclasses

# Deploy a pod using the critical priority class
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: critical-pod
  namespace: production
spec:
  priorityClassName: sre-critical
  containers:
    - name: nginx
      image: nginx
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi
EOF

# Verify the priority is set
kubectl get pod critical-pod -n production -o jsonpath='{.spec.priority}'
```

### Step 6 — Simulate Eviction Behaviour

```bash
# When a node runs out of resources, K8s evicts pods in this order:
# 1. Pods with no resource requests (BestEffort)
# 2. Pods where usage exceeds requests (Burstable)
# 3. Pods using exactly their requests (Guaranteed)
# Priority class overrides this order for equal QoS tier pods

# Check QoS class of a pod
kubectl get pod critical-pod -n production -o jsonpath='{.status.qosClass}'
```

---

## Key Facts For Interviews

```
requiredDuringScheduling   →  Hard requirement — pod stays Pending if no match
preferredDuringScheduling  →  Soft preference — scheduler tries but will place elsewhere

NoSchedule taint           →  New pods cannot schedule here (existing pods stay)
NoExecute taint            →  Existing pods are evicted if they do not tolerate it
PreferNoSchedule taint     →  Scheduler avoids this node but will use it if needed

PDB minAvailable           →  Minimum pods that must be running
PDB maxUnavailable         →  Maximum pods that can be down at once
PDB applies to             →  Voluntary disruptions only (drain, upgrade)
                               NOT to involuntary (node crash, OOM kill)
```

---

## Interview Talking Points

> **Q: How do you ensure critical workloads survive node failures and cluster maintenance?**

> *"I use a combination of pod anti-affinity to spread replicas across nodes so a single node failure cannot take down the entire service, Pod Disruption Budgets to guarantee minimum availability during voluntary disruptions like cluster upgrades and node drains, and Priority Classes to ensure critical system components are the last to be evicted under resource pressure. I also use taints and tolerations to dedicate certain node pools to specific workload types — for example, taint a node pool for GPU workloads and only allow GPU pods to tolerate that taint, which prevents general workloads from consuming GPU node resources."*
