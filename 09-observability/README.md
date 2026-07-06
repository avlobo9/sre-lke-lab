# 09 — Observability on LKE

This section covers the three pillars of observability: metrics, logging, and alerting. On LKE, Akamai provides managed integrations with Prometheus-compatible metrics and log shipping. As an SRE you must be able to set up observability, write meaningful alerts, and use these tools to debug incidents.

---

## Why This Matters For The LKE SRE Role

Observability is the foundation of SRE work. Without it you are flying blind during incidents. On LKE customers often ask why their workloads are slow, why pods are being evicted, or why a deployment failed. Being able to quickly pull metrics, logs, and traces is what separates a reactive firefighter from a proactive SRE.

---

## The Three Pillars

```
Metrics   → Quantitative measurements over time (CPU, memory, request rate, error rate)
Logs      → Discrete events with context (pod logs, audit logs, system logs)
Traces    → Request flow across multiple services (latency breakdown per service)
```

---

## Step By Step Instructions

### Step 1 — Deploy kube-state-metrics

```bash
# kube-state-metrics exposes Kubernetes object state as Prometheus metrics
# It tells you: how many pods are running, pending, failed, etc.
kubectl apply -f kube-state-metrics.yaml

# Verify it is running
kubectl get pods -n monitoring -l app=kube-state-metrics

# Port-forward to check the metrics endpoint
kubectl port-forward -n monitoring svc/kube-state-metrics 8080:8080
# In another terminal:
curl http://localhost:8080/metrics | grep kube_pod_status_phase
```

### Step 2 — Deploy ServiceMonitor For Prometheus Scraping

```bash
kubectl apply -f service-monitor.yaml

# If using the Prometheus Operator, this tells Prometheus which services to scrape
# Verify the ServiceMonitor was created
kubectl get servicemonitor -n monitoring
```

### Step 3 — Deploy The PrometheusRule For Alerting

```bash
kubectl apply -f prometheus-rules.yaml

# These rules will fire alerts when:
# - A pod has been in CrashLoopBackOff for more than 5 minutes
# - Node memory usage exceeds 85%
# - A deployment has no available replicas

# Verify the rules were created
kubectl get prometheusrule -n monitoring
```

### Step 4 — Check Pod Logs

```bash
# Basic log viewing
kubectl logs <pod-name> -n <namespace>

# Follow logs in real time
kubectl logs -f <pod-name> -n <namespace>

# Get logs from previous container instance (after crash)
kubectl logs <pod-name> -n <namespace> --previous

# Get logs from all pods matching a label
kubectl logs -n production -l app=backend --tail=100

# Get logs from a specific container in a multi-container pod
kubectl logs <pod-name> -n <namespace> -c <container-name>

# Get logs from a time window
kubectl logs <pod-name> -n <namespace> --since=1h
kubectl logs <pod-name> -n <namespace> --since-time=2024-01-01T10:00:00Z
```

### Step 5 — Key Metrics To Monitor On LKE

```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage
kubectl top pods -n production
kubectl top pods --all-namespaces --sort-by=memory

# Check HPA status
kubectl get hpa -n production

# Check events for issues
kubectl get events -n production --sort-by=.lastTimestamp
kubectl get events --all-namespaces --field-selector type=Warning
```

### Step 6 — Debugging With Metrics

```bash
# Find pods consuming the most CPU
kubectl top pods --all-namespaces --sort-by=cpu | head -20

# Find pods consuming the most memory
kubectl top pods --all-namespaces --sort-by=memory | head -20

# Check if a node is under memory pressure
kubectl describe node <node-name> | grep -A5 Conditions
kubectl describe node <node-name> | grep -A10 'Allocated resources'

# Check resource requests vs limits vs actual usage
kubectl describe node <node-name> | grep -A30 'Non-terminated Pods'
```

---

## Key Metrics For SRE Work

```
kube_pod_status_phase                    → Pod phase (Running/Pending/Failed)
kube_deployment_status_replicas_available → Available replicas vs desired
kube_node_status_condition               → Node health conditions
container_cpu_usage_seconds_total        → CPU usage per container
container_memory_working_set_bytes       → Memory usage per container
kube_pod_container_status_restarts_total → Restart count (detect crash loops)
node_memory_MemAvailable_bytes           → Available node memory
```

---

## Interview Talking Points

> **Q: How do you approach observability for workloads running on LKE?**

> *"I implement observability in three layers. For metrics I deploy kube-state-metrics to expose Kubernetes object state and use the Prometheus Operator with ServiceMonitors so Prometheus automatically discovers and scrapes new services as they are deployed. I write PrometheusRules for the signals that matter most in production: CrashLoopBackOff for more than five minutes, deployment with zero available replicas, and node memory above 85%. For logging I ensure all application logs go to stdout so kubectl logs works, and for production clusters I ship logs to a centralised store using a DaemonSet log forwarder like Fluent Bit. The most important habit I have developed is checking kubectl get events --field-selector type=Warning immediately when an incident starts, because Kubernetes events often tell you exactly what is wrong before you even need to look at metrics."
```
