terraform {
  backend "s3" {
    bucket  = "mlops-tfstate-mykola"
    key     = "argocd/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
