# 08 — Network Policies

This section demonstrates Kubernetes Network Policies — the mechanism for controlling which pods can communicate with each other and with external endpoints. Network policies are a critical security control in multi-tenant environments like LKE.

---

## Why This Matters For The LKE SRE Role

By default, all pods in a Kubernetes cluster can communicate with all other pods across all namespaces. This is a significant security risk in production. Network Policies allow you to implement a zero-trust network model where communication is explicitly allowed rather than implicitly open.

---

## How Network Policies Work

```
Without Network Policy:     With Network Policy:

Pod A  ──►  Pod B           Pod A  ──►  Pod B  ✓ (explicitly allowed)
Pod A  ──►  Pod C           Pod A  ──►  Pod C  ✗ (no policy = denied)
Pod A  ──►  Internet        Pod A  ──►  Internet ✗ (no policy = denied)

Network Policies are enforced by the CNI plugin (Cilium on LKE).
If the CNI does not support Network Policies, the rules are ignored.
LKE uses Cilium which fully supports Network Policies.
```

---

## Step By Step Instructions

### Step 1 — Create Namespaces

```bash
kubectl create namespace production
kubectl create namespace monitoring
kubectl create namespace staging

# Label namespaces — Network Policies use namespace labels for selection
kubectl label namespace production environment=production
kubectl label namespace monitoring environment=monitoring
kubectl label namespace staging environment=staging
```

### Step 2 — Deploy The Default Deny Policy

Always start with a default deny and then explicitly allow what is needed:

```bash
kubectl apply -f default-deny-all.yaml

# Verify the policy exists
kubectl get networkpolicy -n production

# Test that traffic is now blocked
# Deploy a test pod and try to reach another pod
kubectl run test-pod --image=busybox --rm -it -n production \
  --restart=Never -- wget -qO- --timeout=5 http://some-service
# Should timeout because all ingress is denied
```

### Step 3 — Apply Allow Policies

```bash
# Allow the frontend to talk to the backend
kubectl apply -f allow-frontend-to-backend.yaml

# Allow monitoring to scrape all pods
kubectl apply -f allow-monitoring-ingress.yaml

# Verify all policies
kubectl get networkpolicy -n production
kubectl describe networkpolicy -n production
```

### Step 4 — Test The Policies

```bash
# Deploy test pods
kubectl run frontend --image=busybox -n production \
  --labels=app=frontend --restart=Never -- sleep 3600

kubectl run backend --image=nginx -n production \
  --labels=app=backend --restart=Never

# Test: frontend -> backend (should WORK)
kubectl exec -n production frontend -- \
  wget -qO- --timeout=5 http://backend

# Test: staging -> backend (should FAIL)
kubectl run staging-pod --image=busybox -n staging \
  --restart=Never -- sleep 3600

kubectl exec -n staging staging-pod -- \
  wget -qO- --timeout=5 http://backend.production.svc.cluster.local
# Should timeout

# Clean up test pods
kubectl delete pod frontend backend -n production
kubectl delete pod staging-pod -n staging
```

---

## Common Network Policy Debugging

```bash
# List all network policies across all namespaces
kubectl get networkpolicy --all-namespaces

# Describe a specific policy
kubectl describe networkpolicy default-deny-all -n production

# Check Cilium policy enforcement (LKE uses Cilium)
kubectl exec -n kube-system -it \
  $(kubectl get pods -n kube-system -l k8s-app=cilium -o name | head -1) \
  -- cilium policy get

# Check Cilium endpoint status for a specific pod
kubectl exec -n kube-system \
  $(kubectl get pods -n kube-system -l k8s-app=cilium -o name | head -1) \
  -- cilium endpoint list
```

---

## Interview Talking Points

> **Q: How do you implement network security between microservices in Kubernetes?**

> *"I implement a default-deny Network Policy in every namespace first, then explicitly allow only the traffic that is needed. For example, allow the frontend pods to reach the backend on port 8080, allow the monitoring namespace to scrape metrics on port 9090 from all pods, and allow DNS traffic to kube-dns. On LKE, network policies are enforced by Cilium which provides both standard Kubernetes NetworkPolicy support and its own CiliumNetworkPolicy CRD for more advanced use cases like DNS-based egress filtering. The key debugging approach when network policy issues arise is to use kubectl describe on the policy to verify the pod selector is matching the right pods, and use Cilium's CLI to inspect endpoint policy status directly."*
