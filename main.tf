provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}

module "vpc" {
  source = "./vpc"

  project_name    = var.project_name
  aws_region      = var.aws_region
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

module "eks" {
  source = "./eks"

  use_remote_state = true

  project_name        = var.project_name
  aws_region          = var.aws_region
  cluster_name        = var.cluster_name
  cluster_version     = var.cluster_version
  node_instance_types = var.node_instance_types

  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets
}
