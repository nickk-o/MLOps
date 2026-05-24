variable "project_name" {
  description = "Project name"
  type        = string
  default     = "mlops-mykola"
}

variable "aws_region" {
  description = "AWS region where EKS is running"
  type        = string
  default     = "us-east-1"
}

variable "eks_state_bucket" {
  description = "S3 bucket where EKS Terraform state is stored"
  type        = string
  default     = "mlops-tfstate-mykola"
}

variable "eks_state_key" {
  description = "S3 key for EKS Terraform state"
  type        = string
  default     = "eks/terraform.tfstate"
}

variable "eks_state_region" {
  description = "AWS region of the EKS state bucket"
  type        = string
  default     = "us-east-1"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for Argo CD"
  type        = string
  default     = "infra-tools"
}

variable "argocd_chart_version" {
  description = "Argo CD Helm chart version"
  type        = string
  default     = "7.7.5"
}

variable "app_repo_url" {
  description = "Публічний Git-репозиторій з маніфестами"
  type        = string
  default     = "https://github.com/nickk-o/goit-argo.git"
}

variable "app_repo_branch" {
  description = "Гілка"
  type        = string
  default     = "main"
}
