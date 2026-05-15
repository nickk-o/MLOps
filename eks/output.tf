output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "node_group_names" {
  description = "Created EKS node group names"
  value = [
    "${var.cluster_name}-cpu",
    "${var.cluster_name}-gpu"
  ]
}
