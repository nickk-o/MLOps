# Terraform Infrastructure

Terraform repository for the AWS and Kubernetes infrastructure used in the
project. This repository provisions the base network, the EKS cluster, and the
Argo CD installation. Application workloads are synchronized by Argo CD from a
separate GitOps repository.

## Repositories

This solution uses two repositories:

- Infrastructure repository: `https://github.com/nickk-o/MLOps/tree/lesson-7`
- GitOps repository: `https://github.com/nickk-o/goit-argo.git`

This repository owns:

- AWS infrastructure
- EKS
- Argo CD bootstrap
- the experiment runner in `experiments/`

The `goit-argo` repository owns:

- namespace manifests
- Argo CD `Application` manifests for MLflow, MinIO, PostgreSQL, PushGateway,
  Prometheus, and Grafana

## Project Scope

The repository contains three infrastructure areas:

- `vpc/` creates the AWS VPC and subnets
- `eks/` creates the EKS cluster and worker node groups
- `argocd/` installs Argo CD into the cluster and configures ApplicationSets

This branch also contains the experiment runner and local output directory for
the MLflow assignment:

- `experiments/train_and_push.py`
- `experiments/requirements.txt`
- `best_model/`

## Project Structure

```text
terraform/
├── README.md
├── backend.tf
├── best_model/
├── experiments/
│   ├── requirements.txt
│   └── train_and_push.py
├── main.tf
├── output.tf
├── terraform.tf
├── variables.tf
├── vpc/
├── eks/
├── argocd/
│   ├── backend.tf
│   ├── data.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tf
│   ├── variables.tf
│   └── values/
│       └── argocd-values.yaml
└── docs/
    └── screenshots/
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

`argocd/` installs Argo CD in the `infra-tools` namespace.

The module reads the EKS cluster connection data from remote state and then:

- creates the `infra-tools` namespace
- installs the `argo-cd` Helm chart
- applies custom values from `values/argocd-values.yaml`
- enables the ApplicationSet controller
- creates `namespaces-appset`
- creates `root-application-appset`

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
- root-level `Application` manifests from the `goit-argo` repository

## GitOps Workloads

The GitOps repository contains the manifests required by the assignment:

- `application.yaml` for MLflow Tracking Server
- `minio.yaml` for MinIO with bucket `mlflow-artifacts`
- `postgres.yaml` for PostgreSQL with database `mlflow`
- `pushgateway.yaml` for Prometheus PushGateway
- `prometheus-operator.yaml` for Prometheus and Grafana
- `namespaces/application/ns.yaml`
- `namespaces/infra-tools/ns.yaml`
- `namespaces/monitoring/ns.yaml`

## MLflow Experiment Runner

The experiment runner is implemented in:

- [train_and_push.py](experiments/train_and_push.py)
- [requirements.txt](experiments/requirements.txt)

The script:

- loads the Iris dataset
- trains multiple models with different `learning_rate` and `epochs`
- logs parameters to MLflow
- logs metrics to MLflow
- stores the model as an artifact in MinIO through MLflow
- pushes `mlflow_accuracy` and `mlflow_loss` to PushGateway with the `run_id`
  label
- selects the best run by `accuracy`, then by lower `loss`
- copies the best model artifacts into `best_model/<run_id>/`

## Argo CD Values

`argocd/values/argocd-values.yaml` contains the chart overrides required by the
project:

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
cd vpc
terraform init
terraform plan
terraform apply
```

### 2. Deploy EKS

```bash
cd ../eks
terraform init
terraform plan
terraform apply
```

### 3. Push GitOps Manifests

Run this in the separate `goit-argo` repository:

```bash
git add -A
git commit -m "Update GitOps manifests"
git push origin main
```

### 4. Deploy Argo CD

```bash
cd ../argocd
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
- Argo CD applications created from the GitOps repository

### Verify Application Workloads

```bash
kubectl get pods -n application
kubectl get svc -n application
```

Expected result:

- `mlflow` is running
- `minio` is running
- `mlflow-postgres-postgresql-0` is running
- the `mlflow` service is present on port `5000`
- the `minio` service is present on port `9000`
- the `mlflow-postgres-postgresql` service is present on port `5432`

### Verify Monitoring Workloads

```bash
kubectl get pods -n monitoring
kubectl get svc -n monitoring
```

Expected result:

- `monitoring-grafana` is running
- `prometheus-monitoring-kube-prometheus-prometheus-0` is running
- `pushgateway` is running
- the `pushgateway` service is present on port `9091`

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
kubectl port-forward svc/mlflow 5000:5000 -n application
```

Open:

```text
http://localhost:5000
```

## Access To MinIO

Forward the service locally:

```bash
kubectl port-forward svc/minio 9000:9000 -n application
```

Health check:

```bash
curl http://localhost:9000/minio/health/live
```

## Access To PushGateway

Forward the service locally:

```bash
kubectl port-forward svc/pushgateway 9091:9091 -n monitoring
```

Health check:

```bash
curl http://localhost:9091/-/healthy
```

Cluster service address:

```text
http://pushgateway.monitoring.svc.cluster.local:9091
```

## Access To Grafana

Forward the service locally:

```bash
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
```

Open:

```text
http://localhost:3000
```

## Run The Experiment Script

Create or reuse the virtual environment:

```bash
python3 -m venv experiments/.venv
experiments/.venv/bin/pip install -r experiments/requirements.txt
```

Forward the required services:

```bash
kubectl port-forward svc/mlflow 5000:5000 -n application
kubectl port-forward svc/minio 9000:9000 -n application
kubectl port-forward svc/pushgateway 9091:9091 -n monitoring
```

Run the script from the repository root:

```bash
experiments/.venv/bin/python experiments/train_and_push.py
```

After a successful run:

- MLflow runs are visible in the MLflow UI
- model artifacts are stored in MinIO
- the best model is copied into `best_model/<run_id>/`

## View Metrics In Grafana

Open Grafana and use `Explore` with the Prometheus datasource.

Queries for this assignment:

```text
mlflow_accuracy
mlflow_loss
```

You can use:

- graph view for the metric series
- table view for `run_id`, metric values, and push timestamps

## Acceptance Criteria Coverage

This repository and the connected GitOps repository cover the task
requirements:

- Argo CD is deployed declaratively from Terraform
- MLflow, MinIO, PostgreSQL, PushGateway, Prometheus, and Grafana are deployed
  through Argo CD
- MLflow tracks parameters, metrics, and artifacts
- PushGateway receives `mlflow_accuracy` and `mlflow_loss`
- Grafana can query those metrics through Prometheus
- the best model is copied into `best_model/`
- the repository contains instructions to deploy, verify, port-forward, and
  run the experiment

## Destroy Order

Destroy in reverse dependency order:

1. `argocd/`
2. `eks/`
3. `vpc/`

Commands:

```bash
cd argocd && terraform destroy
cd ../eks && terraform destroy
cd ../vpc && terraform destroy
```
