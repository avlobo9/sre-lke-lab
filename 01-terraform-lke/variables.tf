# variables.tf — Input variable definitions
#
# All configurable values live here.
# Actual values go in terraform.tfvars (gitignored)

variable "linode_token" {
  description = "Linode API token with read/write permissions"
  type        = string
  sensitive   = true  # Prevents token appearing in plan output
}

variable "cluster_name" {
  description = "Name of the LKE cluster"
  type        = string
  default     = "sre-lab"
}

variable "k8s_version" {
  description = "Kubernetes version to deploy. Check available versions with: linode-cli lke versions-list"
  type        = string
  default     = "1.29"
}

variable "region" {
  description = "Linode region. List available regions with: linode-cli regions list"
  type        = string
  default     = "us-east"
}

variable "environment" {
  description = "Environment tag — used for cost tracking and organisation"
  type        = string
  default     = "lab"
}

variable "node_type" {
  description = "Linode plan type for worker nodes. g6-standard-2 = 2vCPU 4GB RAM"
  type        = string
  default     = "g6-standard-2"
}

variable "node_count" {
  description = "Number of worker nodes in the node pool"
  type        = number
  default     = 3
}
