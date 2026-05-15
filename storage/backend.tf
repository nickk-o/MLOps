terraform {
  backend "s3" {
    bucket  = "mlops-tfstate-mykola"
    key     = "s3/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}
