# Terraform Infrastructure

Terraform repository for the AWS and Kubernetes infrastructure used in the
project. The repository provisions the base network, the EKS cluster, and the
Argo CD installation that drives GitOps deployments from a separate manifests
repository.

## Repositories

This solution uses two repositories:

- Infrastructure repository: `https://github.com/nickk-o/MLOps/tree/lesson-7`
- GitOps repository: `https://github.com/nickk-o/goit-argo.git`

This repository owns AWS infrastructure and the Argo CD installation.
`goit-argo` owns the application and namespace manifests that Argo CD
synchronizes from GitHub.

## Project Scope

The repository contains three infrastructure areas:

- `vpc/` creates the AWS VPC and subnets
- `eks/` creates the EKS cluster and worker node groups
- `argocd/` installs Argo CD into the cluster and configures ApplicationSets

## Project Structure

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
├── eks/
│   ├── backend.tf
│   ├── data.tf
│   ├── main.tf
│   ├── output.tf
│   ├── terraform.tf
│   └── variables.tf
└── argocd/
    ├── backend.tf
    ├── data.tf
    ├── main.tf
    ├── outputs.tf
    ├── provider.tf
    ├── terraform.tf
    ├── variables.tf
    └── values/
        └── argocd-values.yaml
```

## Infrastructure Components

### VPC

`vpc/` uses the official `terraform-aws-modules/vpc/aws` module to create:

- the VPC
- public and private subnets
- DNS support and hostnames
- a NAT gateway
- Kubernetes-compatible subnet tags

### EKS

`eks/` uses the official `terraform-aws-modules/eks/aws` module to create:

- the EKS control plane
- public cluster endpoint access
- two managed node groups
- node labels for workload separation

Current workload groups:

- `cpu`
- `gpu`

### Argo CD

`argocd/` installs Argo CD with the Helm provider as a `helm_release` in the
`infra-tools` namespace.

The module reads the EKS cluster connection data from remote state and then:

- creates the `infra-tools` namespace
- installs the `argo-cd` Helm chart
- applies custom values from `values/argocd-values.yaml`
- enables the ApplicationSet controller
- creates ApplicationSets that point Argo CD to the separate GitOps repository

Current GitOps source:

```hcl
app_repo_url    = "https://github.com/nickk-o/goit-argo.git"
app_repo_branch = "main"
```

The Argo CD configuration in `argocd/main.tf` creates:

- `namespaces-appset` for `namespaces/*`
- `root-application-appset` for the repository root

This allows Argo CD to discover:

- namespace manifests from the `goit-argo` repository
- the root `application.yaml` that defines the MLflow Helm deployment

## Argo CD Values

`argocd/values/argocd-values.yaml` contains the chart overrides required by the
task:

- `server.service.type: ClusterIP`
- `server.extraArgs`
- RBAC configuration
- reconciliation timeout
- `applicationSet.enabled: true`

## Prerequisites

Before deployment, make sure you have:

- Terraform `>= 1.5.0`
- AWS CLI configured
- `kubectl` installed
- access to the target AWS account
- an S3 bucket for Terraform state

Check AWS access:

```bash
aws sts get-caller-identity
```

## State And Defaults

Current backend bucket:

```text
mlops-tfstate-mykola
```

Current project defaults:

- AWS region: `us-east-1`
- project name: `mlops-mykola`
- EKS cluster name: `goit-mykola`
- Argo CD namespace: `infra-tools`
- GitOps branch: `main`

## Deployment Order

### 1. Deploy VPC

```bash
cd ~/terraform/vpc
terraform init
terraform plan
terraform apply
```

### 2. Deploy EKS

```bash
cd ~/terraform/eks
terraform init
terraform plan
terraform apply
```

### 3. Push GitOps Manifests

Run this in the separate `goit-argo` repository:

```bash
git add -A
git commit -m "Add GitOps manifests"
git push origin main
```

### 4. Deploy Argo CD

```bash
cd ~/terraform/argocd
terraform init -reconfigure
terraform plan
terraform apply
```

## Verification

### Verify Cluster Access

```bash
aws eks update-kubeconfig --region us-east-1 --name goit-mykola
kubectl get nodes
```

### Verify Argo CD

```bash
kubectl get pods -n infra-tools
kubectl get applicationsets.argoproj.io -n infra-tools
kubectl get applications -n infra-tools
```

Expected result:

- several pods with the `argocd-` prefix
- `namespaces-appset` present
- `root-application-appset` present
- Argo CD Applications created from the GitOps repository

### Verify Workload Deployment

```bash
kubectl get pods -n application
kubectl get svc -n application
```

Expected result:

- the MLflow workload is deployed in `application`
- the `mlflow` service is present

## Access To Argo CD UI

Get the initial admin password:

```bash
kubectl -n infra-tools get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

Forward the Argo CD server locally:

```bash
kubectl port-forward svc/argocd-server -n infra-tools 8080:80
```

Open:

```text
http://localhost:8080
```

## Access To MLflow

Forward the service locally:

```bash
kubectl port-forward svc/mlflow -n application 8081:80
```

Open:

```text
http://localhost:8081
```

## Acceptance Criteria Coverage

This repository covers the infrastructure side of the assignment:

- Argo CD is deployed via Terraform as a `helm_release`
- `argocd-values.yaml` contains the required service, RBAC, extra arguments,
  and timeout settings
- Argo CD is configured to watch the separate GitOps repository
- Argo CD runs in the `infra-tools` namespace

The GitOps repository covers the application side:

- `application.yaml` defines the Helm-based application deployment
- Argo CD synchronizes the application from GitHub
- the target namespace receives the deployed workload

## Destroy Order

Destroy in reverse dependency order:

1. `argocd/`
2. `eks/`
3. `vpc/`

Commands:

```bash
cd ~/terraform/argocd && terraform destroy
cd ~/terraform/eks && terraform destroy
cd ~/terraform/vpc && terraform destroy
```
