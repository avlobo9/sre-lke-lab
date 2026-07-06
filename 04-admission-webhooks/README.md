# 04 — Admission Webhooks

This section demonstrates a validating admission webhook that rejects pods which do not have resource limits set. This is a critical production pattern — without resource limits, a single runaway pod can starve every other workload on the node.

---

## Why This Matters For The LKE SRE Role

On a managed Kubernetes platform like LKE, admission webhooks are how the platform enforces policies at the API server level before any resource is created. Understanding how webhooks work — and how to debug them when they break — is essential SRE knowledge.

---

## How Admission Webhooks Work

```
kubectl apply  →  API Server  →  Authentication
                                      ↓
                             Authorization (RBAC)
                                      ↓
                          Mutating Admission Webhooks
                                      ↓
                         Validating Admission Webhooks  ←  THIS IS WHAT WE BUILD
                                      ↓
                            Persisted to etcd
```

The API server calls your webhook with the full object. Your webhook returns ALLOW or DENY. If it returns DENY, the kubectl apply fails with your custom error message.

---

## What This Webhook Does

- Intercepts every Pod creation request across all namespaces
- Checks that every container in the pod has `resources.limits.cpu` and `resources.limits.memory` set
- Rejects the pod with a clear error message if limits are missing
- Allows the pod through if limits are present

---

## Step By Step Instructions

### Step 1 — Generate TLS Certificates

Webhooks MUST use HTTPS. The API server will not call an HTTP endpoint. Generate a self-signed certificate for the webhook server:

```bash
# Create a directory for certs
mkdir -p certs && cd certs

# Generate a CA key and certificate
openssl genrsa -out ca.key 2048

openssl req -new -x509 -days 365 -key ca.key \
  -subj "/CN=admission-webhook-ca" \
  -out ca.crt

# Generate the webhook server key
openssl genrsa -out webhook.key 2048

# Generate a CSR for the webhook server
# The CN and SAN must match the Kubernetes service DNS name
openssl req -new -key webhook.key \
  -subj "/CN=webhook-service.default.svc" \
  -out webhook.csr

# Create a SAN extension file
cat > webhook-ext.cnf <<EOF
[req]
req_extensions = v3_req
[v3_req]
subjectAltName = DNS:webhook-service.default.svc,DNS:webhook-service.default.svc.cluster.local
EOF

# Sign the certificate with the CA
openssl x509 -req -days 365 \
  -in webhook.csr \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -extensions v3_req \
  -extfile webhook-ext.cnf \
  -out webhook.crt

cd ..
```

### Step 2 — Create The TLS Secret

```bash
kubectl create secret tls webhook-tls \
  --cert=certs/webhook.crt \
  --key=certs/webhook.key
```

### Step 3 — Deploy The Webhook Server

```bash
kubectl apply -f webhook-deployment.yaml
kubectl apply -f webhook-service.yaml

# Verify it is running
kubectl get pods -l app=admission-webhook
kubectl logs -l app=admission-webhook
```

### Step 4 — Get The CA Bundle For The Webhook Config

The ValidatingWebhookConfiguration needs the CA certificate in base64 so the API server can verify the webhook's TLS certificate:

```bash
export CA_BUNDLE=$(cat certs/ca.crt | base64 | tr -d '\n')
echo $CA_BUNDLE
```

### Step 5 — Apply The Webhook Configuration

Replace `REPLACE_ME_CA_BUNDLE` in `validating-webhook-config.yaml` with the value from Step 4, then apply:

```bash
# Replace inline
sed -i "s|REPLACE_ME_CA_BUNDLE|${CA_BUNDLE}|g" validating-webhook-config.yaml

kubectl apply -f validating-webhook-config.yaml
```

### Step 6 — Test The Webhook

**Test 1 — Pod WITHOUT resource limits (should be REJECTED):**

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-no-limits
spec:
  containers:
    - name: nginx
      image: nginx:latest
      # No resources block = webhook should reject this
EOF
```

Expected output:
```
Error from server: admission webhook "validate-resource-limits.sre-lab.io" denied the request:
container nginx is missing resource limits
```

**Test 2 — Pod WITH resource limits (should be ALLOWED):**

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-with-limits
spec:
  containers:
    - name: nginx
      image: nginx:latest
      resources:
        limits:
          cpu: "200m"
          memory: "128Mi"
        requests:
          cpu: "100m"
          memory: "64Mi"
EOF
```

Expected: Pod is created successfully.

### Step 7 — Clean Up

```bash
kubectl delete pod test-with-limits
kubectl delete -f validating-webhook-config.yaml
kubectl delete -f webhook-service.yaml
kubectl delete -f webhook-deployment.yaml
kubectl delete secret webhook-tls
```

---

## Debugging Webhook Failures

Webhooks are a common source of cluster outages. If a webhook server is down and `failurePolicy: Fail` is set, ALL pod creations will fail cluster-wide.

```bash
# Check if the webhook server pod is running
kubectl get pods -l app=admission-webhook

# Check webhook server logs
kubectl logs -l app=admission-webhook

# Check the webhook configuration
kubectl get validatingwebhookconfigurations
kubectl describe validatingwebhookconfiguration resource-limits-validator

# Temporarily disable the webhook in an emergency
kubectl delete validatingwebhookconfiguration resource-limits-validator
```

---

## Interview Talking Points

> **Q: What are admission webhooks and when would you use them?**

> *"Admission webhooks are HTTP callbacks that the Kubernetes API server calls during the admission phase — after authentication and authorization but before the object is persisted to etcd. There are two types: mutating webhooks that can modify objects, and validating webhooks that can only approve or reject them. I built a validating webhook that enforces resource limits on all pods. This is a critical production pattern because without resource limits a single runaway container can starve all other workloads on the node. The most important operational consideration with webhooks is the failurePolicy setting — if you set it to Fail and your webhook server goes down, all pod creations will fail cluster-wide. So webhook servers must be highly available and have their own monitoring."*
