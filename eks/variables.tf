variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "mlops-mykola"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "goit-mykola"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.33"
}

variable "node_instance_types" {
  description = "Instance types for both node groups"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "use_remote_state" {
  description = "Use terraform_remote_state to read VPC outputs"
  type        = bool
  default     = true
}

variable "remote_state_bucket" {
  description = "S3 bucket where VPC terraform state is stored"
  type        = string
  default     = "mlops-tfstate-mykola"
}

variable "remote_state_key" {
  description = "S3 key for VPC terraform state"
  type        = string
  default     = "vpc/terraform.tfstate"
}

variable "remote_state_region" {
  description = "AWS region for remote state bucket"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID, used when use_remote_state = false"
  type        = string
  default     = null
}

variable "public_subnet_ids" {
  description = "Public subnet IDs, used when use_remote_state = false"
  type        = list(string)
  default     = null
}

variable "private_subnet_ids" {
  description = "Private subnet IDs, used when use_remote_state = false"
  type        = list(string)
  default     = null
}
