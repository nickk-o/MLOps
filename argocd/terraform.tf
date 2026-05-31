terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29, < 3.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13, < 3.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0, < 2.0"
    }
  }
}
