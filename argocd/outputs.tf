output "cluster_name" {
  description = "EKS cluster name read from remote state"
  value       = data.terraform_remote_state.eks.outputs.cluster_name
}

output "argocd_namespace" {
  description = "Namespace where Argo CD is installed"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_release_name" {
  description = "Helm release name"
  value       = helm_release.argocd.name
}

output "argocd_server_service" {
  description = "Argo CD server service name"
  value       = "argocd-server"
}

output "get_admin_password_command" {
  description = "Command to get initial Argo CD admin password"
  value       = "kubectl -n ${var.argocd_namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
}

output "port_forward_command" {
  description = "Command to access Argo CD locally"
  value       = "kubectl port-forward svc/argocd-server -n ${var.argocd_namespace} 8080:80"
}

output "bootstrap_application_name" {
  description = "Argo CD bootstrap Application name"
  value       = "mlflow"
}

output "namespaces_appset_name" {
  description = "ApplicationSet that syncs namespace directories from the GitOps repository"
  value       = "namespaces-appset"
}

output "root_application_appset_name" {
  description = "ApplicationSet that syncs root application.yaml from the GitOps repository"
  value       = "root-application-appset"
}
