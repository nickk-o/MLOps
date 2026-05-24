# Lesson 5-6: AWS VPC and EKS with Terraform Modules

This repository contains a modular Terraform project for creating:

- an AWS VPC with the official module `terraform-aws-modules/vpc/aws`
- an AWS EKS cluster with the official module `terraform-aws-modules/eks/aws`
- two EKS managed node groups for different workloads:
  - `cpu`
  - `gpu`

The project is structured as a root stack plus two local modules:

- `vpc/` for networking
- `eks/` for the Kubernetes cluster

## Homework Goal

The homework requires:

- using a modular Terraform structure
- creating a VPC with the official AWS VPC module
- creating an EKS cluster with the official AWS EKS module
- creating two scalable node groups for CPU and GPU workloads
- working with `terraform_remote_state`, outputs, and providers
- connecting to the cluster with `kubectl` after `terraform apply`

This project covers those topics and includes:

- a root `main.tf` that calls both local modules
- separate `vpc/` and `eks/` directories with their own Terraform files
- EKS node labels for workload separation
- `terraform_remote_state` support in `eks/data.tf`

## Important Cost Warning

When working with AWS, unused resources can generate charges.

- Always destroy resources after verification with `terraform destroy`
- You may keep the S3 bucket that stores Terraform state if you still need it
- AWS S3 storage cost is approximately `$0.023 per GB / month`

Recommended destroy order:

1. Destroy EKS
2. Destroy VPC
3. Keep or remove the S3 state bucket only if you are sure it is no longer needed

## Project Structure

Current repository structure:

```text
terraform/
├── README.md
├── backend.tf
├── main.tf
├── output.tf
├── terraform.tf
├── variables.tf
├── vpc/
│   ├── backend.tf
│   ├── main.tf
│   ├── output.tf
│   ├── terraform.tf
│   └── variables.tf
└── eks/
    ├── backend.tf
    ├── data.tf
    ├── main.tf
    ├── output.tf
    ├── terraform.tf
    └── variables.tf
```

## What Each Part Does

### Root Module

The root module in [main.tf](terraform/main.tf) does the orchestration:

- configures the AWS provider
- calls `module "vpc"` from `./vpc`
- calls `module "eks"` from `./eks`
- passes VPC outputs into the EKS module

The root module also defines:

- shared input variables in [variables.tf](/terraform/variables.tf)
- root outputs in [output.tf](/terraform/output.tf)
- required provider versions in [terraform.tf](/terraform/terraform.tf)
- the S3 backend in [backend.tf](/terraform/backend.tf)

### `vpc/` Module

The VPC module in [vpc/main.tf](/terraform/vpc/main.tf):

- uses `terraform-aws-modules/vpc/aws`
- creates the VPC, public subnets, and private subnets
- enables DNS support and DNS hostnames
- creates a single NAT gateway
- adds subnet tags required for AWS load balancers in Kubernetes

The module exports:

- `vpc_id`
- `public_subnets`
- `private_subnets`
- `azs`

### `eks/` Module

The EKS module in [eks/main.tf](/terraform/eks/main.tf):

- uses `terraform-aws-modules/eks/aws`
- creates an EKS cluster
- enables public cluster endpoint access
- enables cluster creator admin permissions
- creates two managed node groups:
  - `cpu`
  - `gpu`

Both node groups currently use:

- `t3.medium`
- `min_size = 1`
- `desired_size = 1`
- `max_size = 2`

Node labels:

- CPU group: `workload=cpu`, `nodegroup=cpu`
- GPU group: `workload=gpu`, `nodegroup=gpu`

## `terraform_remote_state` 

- when `use_remote_state = true`, the EKS module reads VPC outputs from the VPC state stored in S3
- when `use_remote_state = false`, the EKS module accepts VPC values directly from the root module

## Prerequisites

Before deployment, make sure you have:

- Terraform `>= 1.5.0`
- AWS CLI configured
- `kubectl` installed
- access to an AWS account
- an existing S3 bucket for Terraform state

Check AWS access:

```bash
aws sts get-caller-identity
```

Current backend bucket names in this project:

```text
mlops-tfstate-mykola
```

State keys used by the project:

- root: `root/terraform.tfstate`
- VPC: `vpc/terraform.tfstate`
- EKS: `eks/terraform.tfstate`

If you use another bucket name, update the backend configuration files before running `terraform init`.

## Key Variables

Important defaults from the current project:

- AWS region: `us-east-1`
- project name: `mlops-mykola`
- cluster name: `goit-mykola`
- Kubernetes version: `1.33`
- VPC CIDR: `10.0.0.0/16`
- public subnets: `10.0.1.0/24`, `10.0.2.0/24`
- private subnets: `10.0.11.0/24`, `10.0.12.0/24`
- node instance type: `t3.medium`

## Deployment Options

There are two reasonable ways to use this repository.

### Option 1: Deploy Root Stack

Use the root stack when you want one entry point that runs both modules:

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

### Option 2: Deploy Modules Separately

Use separate module deployment when you want to work with the `terraform_remote_state` approach more explicitly.

Deploy VPC first:

```bash
cd vpc
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Then deploy EKS:

```bash
cd ../eks
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

If you deploy `eks/` separately and want it to read VPC outputs from remote state, ensure:

- `use_remote_state = true`
- the remote state bucket, key, and region match the VPC backend

## Access the Cluster

After `terraform apply`, configure `kubectl`:

```bash
aws eks --region us-east-1 update-kubeconfig \
  --name goit-mykola \
```

Check the cluster:

```bash
kubectl get nodes
kubectl get nodes -L workload,nodegroup
```

Expected result:

- the EKS cluster is reachable
- two managed node groups are present
- node labels show `cpu` and `gpu` workloads

## Destroy Resources

Destroy EKS first:

```bash
cd eks
terraform destroy
```

Then destroy VPC:

```bash
cd ../vpc
terraform destroy
```

If you used the root stack as a single entry point, destroy from the root:

```bash
terraform destroy
```

Be careful with backend storage:

- do not remove the S3 state bucket unless you intentionally want to delete stored state
- if the bucket is deleted, future Terraform runs may need backend reconfiguration
