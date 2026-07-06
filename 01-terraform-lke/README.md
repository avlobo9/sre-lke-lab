# 01 — Provision LKE Cluster with Terraform

This section provisions a real Linode Kubernetes Engine (LKE) cluster using Terraform. This is the foundation for every other section in this lab.

---

## Why This Matters For SRE

Infrastructure as Code (IaC) is a core SRE practice. Manually clicking through a UI to create clusters does not scale and cannot be version controlled or reviewed. Terraform lets you define your cluster declaratively, track changes in git, and reproduce environments reliably.

The LKE JD specifically lists Terraform as a required skill.

---

## Prerequisites

- Linode account created at https://www.linode.com
- Terraform installed (`terraform -version` should return 1.0+)
- A Linode API token with full read/write permissions

---

## Step 1 — Generate a Linode API Token

1. Log in to https://cloud.linode.com
2. Click your profile icon top right → **API Tokens**
3. Click **Create a Personal Access Token**
4. Set expiry to 90 days, select all permissions, click **Create Token**
5. Copy the token — you will not see it again

---

## Step 2 — Set Your Token As An Environment Variable

```bash
export LINODE_TOKEN="your_token_here"
```

Add this to your `~/.zshrc` or `~/.bashrc` so it persists across sessions.

---

## Step 3 — Copy The Example Variables File

```bash
cd 01-terraform-lke
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in your values. The file is gitignored so your token never gets committed.

---

## Step 4 — Initialise Terraform

```bash
terraform init
```

This downloads the Linode provider plugin. You should see:
```
Terraform has been successfully initialized!
```

---

## Step 5 — Preview What Will Be Created

```bash
terraform plan
```

Review the output. You should see one LKE cluster and one node pool being created. No changes are made yet.

---

## Step 6 — Create The Cluster

```bash
terraform apply
```

Type `yes` when prompted. This takes approximately 3 to 5 minutes. When complete you will see:
```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

---

## Step 7 — Export The Kubeconfig

```bash
# Terraform outputs the kubeconfig as a file
terraform output -raw kubeconfig | base64 -d > ~/.kube/lke-config

# Set kubectl to use it
export KUBECONFIG=~/.kube/lke-config
```

---

## Step 8 — Verify The Cluster Is Ready

```bash
kubectl get nodes
```

Expected output:
```
NAME                        STATUS   ROLES    AGE   VERSION
lke-sre-lab-node-xxxxxx     Ready    <none>   2m    v1.29.x
lke-sre-lab-node-xxxxxx     Ready    <none>   2m    v1.29.x
lke-sre-lab-node-xxxxxx     Ready    <none>   2m    v1.29.x
```

All three nodes should show `Ready`.

---

## Step 9 — Explore The Cluster

```bash
# Check all system pods are running
kubectl get pods -n kube-system

# Check cluster info
kubectl cluster-info

# Check available API resources
kubectl api-resources
```

---

## Destroy The Cluster When Not In Use

To avoid unnecessary cost, destroy the cluster when you are done for the day:

```bash
terraform destroy
```

Your Terraform state is saved locally so you can recreate it identically any time.

---

## Interview Talking Points

**Q: How do you provision Kubernetes clusters?**
> "I use Terraform with the Linode provider to provision LKE clusters declaratively. I define the cluster version, node pool size, and tags in variables so the same code can create dev and production environments. The kubeconfig is output by Terraform and stored securely. This gives me full version history of infrastructure changes in git."

**Q: Why Terraform over the Linode UI?**
> "Terraform makes cluster creation reproducible, reviewable, and auditable. If a cluster needs to be recreated after a failure, I can do it in under 5 minutes with a single command rather than manually recreating settings through a UI. It also enforces that all infrastructure changes go through a review process."

**Q: How do you manage Terraform state in production?**
> "In production I would use a remote backend such as Terraform Cloud or an S3-compatible object store to share state across the team and prevent concurrent modifications. State locking prevents two engineers from applying changes simultaneously which could corrupt the cluster configuration."
