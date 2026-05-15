locals {
  vpc_id = var.use_remote_state ? data.terraform_remote_state.vpc[0].outputs.vpc_id : var.vpc_id

  public_subnet_ids = var.use_remote_state ? data.terraform_remote_state.vpc[0].outputs.public_subnets : var.public_subnet_ids

  private_subnet_ids = var.use_remote_state ? data.terraform_remote_state.vpc[0].outputs.private_subnets : var.private_subnet_ids
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                   = local.vpc_id
  subnet_ids               = local.private_subnet_ids
  control_plane_subnet_ids = local.private_subnet_ids

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }

    eks-pod-identity-agent = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {
      most_recent = true
    }
  }

  eks_managed_node_group_defaults = {
    instance_types = var.node_instance_types
    ami_type       = "AL2023_x86_64_STANDARD"
    disk_size      = 20
  }

  eks_managed_node_groups = {
    cpu = {
      name = "${var.cluster_name}-cpu"

      instance_types = var.node_instance_types

      min_size     = 1
      max_size     = 2
      desired_size = 1

      labels = {
        workload  = "cpu"
        nodegroup = "cpu"
      }

      tags = {
        Name = "${var.cluster_name}-cpu"
      }
    }

    gpu = {
      name = "${var.cluster_name}-gpu"

      instance_types = var.node_instance_types

      min_size     = 1
      max_size     = 2
      desired_size = 1

      labels = {
        workload  = "gpu"
        nodegroup = "gpu"
      }

      tags = {
        Name = "${var.cluster_name}-gpu"
      }
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
