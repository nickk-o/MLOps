module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  public_subnet_names = [
    for az in var.azs : "${var.project_name}-public-subnet-${az}"
  ]

  private_subnet_names = [
    for az in var.azs : "${var.project_name}-private-subnet-${az}"
  ]

  enable_dns_support   = true
  enable_dns_hostnames = true

  enable_nat_gateway = true
  single_nat_gateway = true

  map_public_ip_on_launch = true

  public_subnet_tags = {
    Type                     = "public"
    Tier                     = "public"
    Visibility               = "public"
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    Type                              = "private"
    Tier                              = "private"
    Visibility                        = "private"
    "kubernetes.io/role/internal-elb" = "1"
  }

  public_route_table_tags = {
    Name = "${var.project_name}-public-route-table"
    Type = "public"
  }

  private_route_table_tags = {
    Name = "${var.project_name}-private-route-table"
    Type = "private"
  }

  igw_tags = {
    Name = "${var.project_name}-internet-gateway"
    Type = "internet-gateway"
  }

  nat_gateway_tags = {
    Name = "${var.project_name}-nat-gateway"
    Type = "nat-gateway"
  }

  nat_eip_tags = {
    Name = "${var.project_name}-nat-eip"
    Type = "elastic-ip"
  }

  default_route_table_name = "${var.project_name}-default-route-table"

  default_route_table_tags = {
    Name = "${var.project_name}-default-route-table"
    Type = "default"
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
