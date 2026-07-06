# outputs.tf — Values to display after terraform apply
#
# These outputs let you retrieve important cluster information
# without logging into the Linode Cloud Manager

output "cluster_id" {
  description = "The unique ID of the LKE cluster"
  value       = linode_lke_cluster.sre_lab.id
}

output "cluster_status" {
  description = "Current status of the LKE cluster"
  value       = linode_lke_cluster.sre_lab.status
}

output "api_endpoints" {
  description = "Kubernetes API server endpoints"
  value       = linode_lke_cluster.sre_lab.api_endpoints
}

output "kubeconfig" {
  description = "Base64 encoded kubeconfig. Decode with: terraform output -raw kubeconfig | base64 -d"
  value       = linode_lke_cluster.sre_lab.kubeconfig
  sensitive   = true  # Prevents kubeconfig appearing in plain text logs
}

output "node_pool_id" {
  description = "ID of the worker node pool"
  value       = linode_lke_cluster.sre_lab.pool[0].id
}
