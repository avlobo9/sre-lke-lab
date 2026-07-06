# SRE LKE Lab

A complete hands-on lab environment for Senior SRE engineers targeting the Akamai Linode Kubernetes Engine (LKE) platform. Every section builds real, demonstrable knowledge you can speak to confidently in a Senior SRE interview.

---

## Prerequisites

Before starting, install the following on your local machine:

```bash
# Terraform
brew install terraform        # macOS
# or https://developer.hashicorp.com/terraform/install

# kubectl
brew install kubectl          # macOS
# or https://kubernetes.io/docs/tasks/tools/

# etcdctl (for etcd operations)
brew install etcd             # macOS - installs etcdctl too

# openssl (usually pre-installed)
openssl version

# Linode CLI (optional but useful)
pip3 install linode-cli
```

You also need:
- A [Linode account](https://www.linode.com) with API token generated
- A GitHub account to document your findings

---

## Learning Path

Work through the sections in order. Each one builds on the last.

| Section | Topic | Skills Built | Interview Weight |
|---------|-------|-------------|------------------|
| [01](./01-terraform-lke/) | Provision LKE with Terraform | IaC, cluster provisioning, cloud provider integration | High |
| [02](./02-prometheus-stack/) | Deploy full observability stack | Prometheus, Alertmanager, Grafana, alerting | High |
| [03](./03-rbac/) | RBAC deep dive | Security, least privilege, service accounts | High |
| [04](./04-admission-webhooks/) | Admission webhooks | Policy enforcement, API server flow | Medium |
| [05](./05-etcd-operations/) | etcd operations | Control plane, backup, restore, health | High |
| [06](./06-node-affinity-taints/) | Node affinity and taints | Workload placement, PDBs, priority classes | Medium |
| [07](./07-persistent-volumes/) | Persistent volumes on LKE | Cloud provider storage integration, CCM | Medium |
| [08](./08-node-failure-simulation/) | Node failure simulation | Incident response, resilience, observability | High |
| [09](./09-api-server-audit/) | API server audit logging | Security, forensics, incident investigation | Medium |

---

## How To Reference This In Interviews

When an interviewer asks about your Kubernetes experience:

> *"I have been building hands-on experience with LKE specifically because it is the platform your team supports. I provisioned an LKE cluster using Terraform, deployed a full observability stack with Prometheus, Alertmanager and Grafana, and have worked through control plane operations including etcd backup procedures, RBAC configuration, admission webhooks, and persistent volume provisioning using Linode block storage. I documented everything on GitHub so I could track what I learned and what broke along the way."*

Then reference this repo directly.

---

## Repository Structure

```
sre-lke-lab/
├── 01-terraform-lke/           # Provision LKE cluster with Terraform
├── 02-prometheus-stack/        # Full observability stack
├── 03-rbac/                    # RBAC configuration
├── 04-admission-webhooks/      # Validating webhook example
├── 05-etcd-operations/         # etcd backup, restore, health
├── 06-node-affinity-taints/    # Workload placement patterns
├── 07-persistent-volumes/      # Linode block storage integration
├── 08-node-failure-simulation/ # Node failure and recovery
└── 09-api-server-audit/        # API server audit logging
```

---

## Cost Estimate

Running this full lab on Linode costs approximately **$30 to $50 per month** for a 3-node cluster using g6-standard-2 plans. Destroy the cluster with `terraform destroy` when not actively using it to minimize cost.
