# 02 — Deploy Full Observability Stack

This section deploys Prometheus, Alertmanager, and Grafana using raw Kubernetes manifests. We use manifests instead of Helm so you understand every component and can speak to it in detail during interviews.

---

## Why This Matters For The LKE SRE Role

The LKE JD specifically asks for experience with Prometheus and Grafana. More importantly, the SRE role requires you to own SLOs and detect platform issues before customers do. This stack is how you do that.

---

## Step By Step Instructions

### Step 1 — Create The Monitoring Namespace

```bash
kubectl apply -f namespace.yaml
kubectl get namespace monitoring
```

### Step 2 — Deploy Prometheus

```bash
kubectl apply -f prometheus-configmap.yaml
kubectl apply -f prometheus-deployment.yaml
kubectl apply -f prometheus-service.yaml
```

Verify Prometheus is running:
```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring -l app=prometheus
```

### Step 3 — Deploy Alertmanager

Before applying, edit `alertmanager-configmap.yaml` and replace `REPLACE_ME_SLACK_WEBHOOK` with your Slack webhook URL.

```bash
kubectl apply -f alertmanager-configmap.yaml
kubectl apply -f alertmanager-deployment.yaml
kubectl apply -f alertmanager-service.yaml
```

### Step 4 — Deploy Alert Rules

```bash
kubectl apply -f alerts/node-alerts.yaml
kubectl apply -f alerts/pod-alerts.yaml
```

### Step 5 — Deploy Grafana

```bash
kubectl apply -f grafana-deployment.yaml
kubectl apply -f grafana-service.yaml
```

### Step 6 — Access The UIs

```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090
# Open http://localhost:9090

# Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
# Open http://localhost:9093

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000
# Login: admin / REPLACE_ME_PASSWORD
```

### Step 7 — Verify Metrics Are Being Scraped

In the Prometheus UI go to **Status → Targets** and verify all targets show as UP.

Run these PromQL queries to verify data is flowing:

```promql
# Node CPU usage
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node memory usage percent
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pods not running
count(kube_pod_status_phase{phase!="Running",phase!="Succeeded"}) by (namespace, phase)

# HTTP error rate
rate(http_requests_total{status=~"5.."}[5m])
```

---

## What To Observe

- How Prometheus discovers targets via Kubernetes service discovery
- How AlertManager groups and routes alerts to Slack
- How recording rules reduce query complexity at scale
- How Grafana connects to Prometheus as a data source

---

## Interview Talking Points

> **Q: Tell me about your experience with Prometheus and Grafana.**

> *"I deployed a full Prometheus stack using raw Kubernetes manifests including Prometheus, Alertmanager, and Grafana. I configured scrape targets using Kubernetes service discovery, wrote alerting rules for node CPU and memory pressure, pod CrashLoopBackOff, and PVC binding failures, and routed alerts to Slack via Alertmanager. I also wrote PromQL queries for error rate calculation, latency percentiles, and capacity forecasting. I specifically chose raw manifests over Helm so I would understand every component at the YAML level."*
