# main.tf — Provision an LKE cluster on Linode
#
# This file defines the Linode provider and creates:
# - One LKE cluster
# - One node pool with 3 nodes

terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.0"
}

# Configure the Linode provider
# The token is read from the LINODE_TOKEN environment variable
provider "linode" {
  token = var.linode_token
}

# Create the LKE cluster
resource "linode_lke_cluster" "sre_lab" {
  # Cluster name — visible in the Linode Cloud Manager
  label = var.cluster_name

  # Kubernetes version — check available versions with:
  # linode-cli lke versions-list
  k8s_version = var.k8s_version

  # Region — choose closest to you
  # List regions: linode-cli regions list
  region = var.region

  # Tags for organisation and cost tracking
  tags = ["sre-lab", "terraform", var.environment]

  # Node pool definition
  pool {
    # Plan type — g6-standard-2 is 2 vCPU, 4GB RAM
    # List plans: linode-cli linodes types
    type  = var.node_type

    # Number of nodes in the pool
    count = var.node_count

    # Autoscaler configuration — optional but good to know
    autoscaler {
      min = var.node_count
      max = var.node_count + 2
    }
  }
}
