variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "mlops-mykola"
}

variable "bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
  default     = "mlops-tfstate-mykola"
}
