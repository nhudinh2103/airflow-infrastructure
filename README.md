# Infrastructure

This repository contains infrastructure-related configurations and helm charts as git submodules.

## Structure

- `terraform/` - Contains Terraform configurations for infrastructure provisioning
- `config-sync/` - Contains Config Sync configurations for Kubernetes
- `airflow/` - Airflow helm charts (submodule)
- `github-runner/` - GitHub Runner helm charts (submodule)
- `sealed-secrets/` - Sealed Secrets helm charts (submodule)

## Git Submodules

The following repositories are included as git submodules:

- airflow: https://gitlab.com/personal2144607/infras/airflow.git
- github-runner: git@gitlab.com:personal2144607/infras/github-runner.git
- sealed-secrets: git@gitlab.com:personal2144607/infras/sealed-secrets.git

## First Time Setup

To clone this repository and all its submodules:

```bash
# Clone the repository with its submodules
git clone --recursive [repository-url]

# Or if you've already cloned the repository:
git submodule init
git submodule update
```

## Updating Submodules

To update all submodules to their latest commits:

```bash
git submodule update --remote --merge
```

Or update a specific submodule:

```bash
cd [submodule-directory]
git checkout main  # or your desired branch
git pull
cd ..
git add [submodule-directory]
git commit -m "Update [submodule-name] submodule"
```

## Terraform Usage Guide

### Prerequisites

1. Install Terraform (version >= 1.0.0)
2. Configure Google Cloud SDK and authenticate
3. Enable required Google Cloud APIs:
   - Kubernetes Engine API
   - Container Registry API
   - Cloud Resource Manager API
   - Cloud SQL Admin API

### Configuration

1. Create a terraform.tfvars file in the terraform directory:

```hcl
project_id         = "your-project-id"
network            = "your-vpc-network"
subnetwork         = "your-subnet"
ip_range_pods      = "your-pods-range"
ip_range_services  = "your-services-range"
service_account    = "your-service-account@your-project.iam.gserviceaccount.com"
nfs_server         = "your-nfs-server-ip"
```

### Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| project_id | GCP Project ID | (required) |
| cluster_name | GKE cluster name | dinhnnpoc-airflow-test-cluster |
| zone | GCP zone | asia-southeast1-c |
| network | VPC network name | (required) |
| subnetwork | Subnet name | (required) |
| ip_range_pods | Secondary IP range for pods | (required) |
| ip_range_services | Secondary IP range for services | (required) |
| service_account | GCP service account | (required) |
| authorized_ipv4_cidr | Authorized network CIDR | 42.119.80.24/32 |
| nfs_server | NFS server IP address | (required) |
| nfs_path_logs | NFS path for Airflow logs | /mnt/disks/airflow-disk/airflow/logs |
| nfs_path_dags | NFS path for Airflow DAGs | /mnt/disks/airflow-disk/airflow/dags |
| db_instance_name | Cloud SQL instance name | airflow-db |
| db_region | Cloud SQL instance region | asia-southeast1 |
| db_password | Cloud SQL postgres user password | (required) |

### Cloud SQL Configuration

The infrastructure includes a Cloud SQL PostgreSQL instance for Airflow's metadata database. The instance is configured with:
- PostgreSQL 17
- Custom machine type (db-custom-1-3840)
- 10GB SSD storage
- Automated backups and point-in-time recovery
- Public IP access (configurable for private IP)

#### Setting Database Password

For security, the database password should be provided via environment variable:

```bash
# Option 1: Export the variable (password persists in shell session)
export TF_VAR_db_password='your-secure-password'
terraform plan -var-file="terraform.tfvars.airflow-gke-poc1"

# Option 2: Set inline (more secure, password not stored in shell history)
TF_VAR_db_password='your-secure-password' terraform plan -var-file="terraform.tfvars.airflow-gke-poc1"
```

Password requirements:
- Minimum 8 characters
- Mix of letters, numbers, and special characters

### Deployment Steps

1. Initialize Terraform:
```bash
cd terraform
terraform init
```

2. Review the deployment plan:
```bash
terraform plan
```

3. Apply the configuration:
```bash
terraform apply
```

### Common Operations

1. Update cluster configuration:
```bash
terraform plan    # Review changes
terraform apply   # Apply changes
```

2. Scale node pools:
   - Modify the min_count and max_count in main.tf node_pools configuration
   - Run terraform apply

3. Destroy infrastructure:
```bash
terraform destroy
```
