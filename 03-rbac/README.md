# 03 — RBAC Deep Dive

This section configures Role-Based Access Control (RBAC) across multiple namespaces. RBAC is one of the most common Senior SRE interview topics because misconfigured RBAC causes both security incidents and operational failures.

---

## Why This Matters For The LKE SRE Role

On LKE, every customer workload runs with RBAC enforced. As an SRE you will configure service account permissions, debug permission denied errors, and design least-privilege access models for internal tooling.

---

## What We Are Building

```
Namespaces:  dev | staging | production

dev          → read-only access for all service accounts
staging      → read/write for deployments and pods
production   → full access, tightly controlled
ClusterRole  → cross-namespace read for SRE monitoring tools
```

---

## Step By Step Instructions

### Step 1 — Create The Namespaces

```bash
kubectl apply -f namespaces.yaml
kubectl get namespaces
```

You should see dev, staging, and production listed.

### Step 2 — Create Service Accounts

```bash
kubectl apply -f service-accounts.yaml
kubectl get serviceaccounts -n dev
kubectl get serviceaccounts -n staging
kubectl get serviceaccounts -n production
```

### Step 3 — Create Roles

```bash
kubectl apply -f roles.yaml
kubectl get roles -n dev
kubectl get roles -n staging
kubectl get roles -n production
```

### Step 4 — Create Role Bindings

```bash
kubectl apply -f rolebindings.yaml
kubectl get rolebindings -n dev
```

### Step 5 — Create Cluster Role For SRE Tools

```bash
kubectl apply -f clusterroles.yaml
kubectl get clusterroles | grep sre
```

### Step 6 — Verify Permissions With kubectl auth can-i

```bash
# Dev service account should NOT be able to delete pods
kubectl auth can-i delete pods \
  --namespace dev \
  --as system:serviceaccount:dev:dev-app
# Expected: no

# Dev service account should be able to get pods
kubectl auth can-i get pods \
  --namespace dev \
  --as system:serviceaccount:dev:dev-app
# Expected: yes

# Production service account should be able to delete pods
kubectl auth can-i delete pods \
  --namespace production \
  --as system:serviceaccount:production:prod-app
# Expected: yes

# SRE monitoring account should be able to list pods across namespaces
kubectl auth can-i list pods \
  --all-namespaces \
  --as system:serviceaccount:monitoring:sre-monitor
# Expected: yes
```

### Step 7 — Simulate A Permission Denied Error And Debug It

```bash
# Try to do something the dev account cannot do
kubectl auth can-i create deployments \
  --namespace dev \
  --as system:serviceaccount:dev:dev-app

# If you get no, investigate which role is bound
kubectl get rolebindings -n dev -o yaml
kubectl get role dev-readonly -n dev -o yaml
```

This is exactly what you do in production when a pod gets a permission denied error in its logs.

---

## Interview Talking Points

> **Q: How do you approach RBAC design in a production Kubernetes cluster?**

> *"I follow the principle of least privilege. Each namespace gets its own service account with only the permissions that workload actually needs. I use Roles for namespace-scoped permissions and ClusterRoles only when cross-namespace access is genuinely required, like for SRE monitoring tools. I verify all permissions with kubectl auth can-i before deploying, and I audit RBAC configs regularly to remove permissions that are no longer needed. In production I also use admission webhooks to reject pods that request overly broad service account permissions."*
