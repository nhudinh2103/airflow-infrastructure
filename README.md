# Infrastructure

This repository contains infrastructure-related configurations and helm charts as git submodules.

## Structure

- `terraform/` - Contains Terraform configurations for infrastructure provisioning
- `airflow/` - Airflow helm charts (submodule)
- `github-runner/` - GitHub Runner helm charts (submodule)
- `sealed-secrets/` - Sealed Secrets helm charts (submodule)
- `csi-driver-nfs/` - NFS CSI Driver helm charts for dynamic NFS provisioning (submodule)

## Git Submodules

The following repositories are included as git submodules:

- airflow: https://gitlab.com/personal2144607/infras/airflow.git
- github-runner: git@gitlab.com:personal2144607/infras/github-runner.git
- sealed-secrets: git@gitlab.com:personal2144607/infras/sealed-secrets.git
- csi-driver-nfs: git@gitlab.com:personal2144607/infras/csi-driver-nfs.git

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
3. Set up service account with required permissions:

```bash
# Set variables
PROJECT_ID="your-project-id"
SA_NAME="rancher-provision-gke"
SA_DISPLAY_NAME="Service Account for GKE and Cloud SQL provisioning"
ROOT_EMAIL="root-email@example.com"  # Root account email

# 1. Switch to root account first
echo "Switching to root account..."
gcloud config set account $ROOT_EMAIL

# 2. Create service account
gcloud iam service-accounts create $SA_NAME \
  --project=$PROJECT_ID \
  --display-name="$SA_DISPLAY_NAME"

# 3. Get the full service account email
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

# 4. Grant necessary roles (as root)
echo "Granting roles to service account..."
# Core functionality roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/container.admin"        # For GKE management

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/container.clusterViewer" # For listing cluster versions

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/cloudsql.admin"        # For Cloud SQL management

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/compute.admin"         # For compute resources (NFS)

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.serviceAccountUser" # For using service accounts

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/storage.admin"         # For GCR access

# Add IAM roles for policy management
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/iam.securityReviewer"  # For viewing IAM policies

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/resourcemanager.projectIamAdmin"  # For modifying IAM policies

# 5. Create and download service account key
echo "Creating service account key..."
gcloud iam service-accounts keys create key.json \
  --iam-account=$SA_EMAIL

# 6. Test service account permissions
gcloud auth activate-service-account $SA_EMAIL \
  --key-file=key.json \
  --project=$PROJECT_ID

# Test permissions
echo "Testing permissions..."
gcloud projects get-iam-policy $PROJECT_ID
gcloud container clusters list --project=$PROJECT_ID
gcloud sql instances list --project=$PROJECT_ID
gcloud compute instances list --project=$PROJECT_ID

# 7. Switch back to root account
echo "Switching back to root account..."
gcloud config set account $ROOT_EMAIL
```

These roles provide the following permissions:
- container.admin: Create and manage GKE clusters
- container.clusterViewer: View and list cluster versions
- cloudsql.admin: Create and manage Cloud SQL instances
- compute.admin: Manage compute resources (needed for NFS)
- iam.serviceAccountUser: Use service accounts
- storage.admin: Access to Container Registry
- iam.securityReviewer: View IAM policies (needed for Terraform)
- resourcemanager.projectIamAdmin: Modify IAM policies

Important notes:
1. Replace placeholders with your actual values
2. Root account should have Organization/Project Admin privileges
3. Keep key.json secure and never commit it to version control
4. For production, consider using Workload Identity instead of service account keys

4. Enable required Google Cloud APIs:

```bash
# Enable required APIs
gcloud services enable \
    container.googleapis.com \
    containerregistry.googleapis.com \
    cloudresourcemanager.googleapis.com \
    sqladmin.googleapis.com
```

The above command enables:
   - Kubernetes Engine API (container.googleapis.com)
   - Container Registry API (containerregistry.googleapis.com)
   - Cloud Resource Manager API (cloudresourcemanager.googleapis.com)
   - Cloud SQL Admin API (sqladmin.googleapis.com)

### Configuration

See terraform.tfvars.example for a template configuration file. Copy this file to terraform.tfvars and update the values according to your environment.

### Required Variables

| Variable | Description | Required | Example |
|----------|-------------|----------|---------|
| project_id | GCP Project ID where resources will be created | Yes | my-project-123 |
| airflow_repository | Container registry path for Airflow images | Yes | gcr.io/my-project/airflow |
| cluster_name | Name of the GKE cluster | Yes | my-airflow-cluster |
| zone | GCP zone for resources | Yes | asia-southeast1-c |
| default_storage_class | Kubernetes storage class for persistent volumes | Yes | standard-rwo |
| network | VPC network name | Yes | default |
| subnetwork | Subnet name within the VPC | Yes | default |
| ip_range_pods | Secondary IP range name for pods | Yes | gke-pods |
| ip_range_services | Secondary IP range name for services | Yes | gke-services |
| service_account | Service account email for GKE nodes | Yes | service-account@project.iam.gserviceaccount.com |
| authorized_ipv4_cidr | CIDR range for authorized access to GKE master | Yes | 192.168.1.100/32 |
| sealed_secret_public_cert | Path to sealed secrets public certificate | Yes | public_cert.pem |
| nfs_path_logs | NFS mount path for Airflow logs | Yes | /mnt/disks/airflow-disk/airflow/logs |
| nfs_path_dags | NFS mount path for Airflow DAGs | Yes | /mnt/disks/airflow-disk/airflow/dags |
| db_instance_name | Name for the Cloud SQL instance | Yes | airflow-db |
| db_region | Region for the Cloud SQL instance | Yes | asia-southeast1 |
| db_password | Cloud SQL postgres user password | Yes | Set via TF_VAR_db_password |

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

### Ingress Configuration

The infrastructure uses a GCP HTTP(S) Load Balancer configured through a Kubernetes Ingress resource. The GKE cluster is pre-configured with HTTP load balancing enabled through the terraform configuration.

Prerequisites:
```bash
# Enable required APIs for load balancing
gcloud services enable \
    compute.googleapis.com \
    certificatemanager.googleapis.com
```

The setup requires manual creation of:

1. Static IP Address:
   ```bash
   # Reserve a global static IP
   gcloud compute addresses create poc-click-ip --global
   
   # Get the IP address
   gcloud compute addresses describe poc-click-ip --global --format='get(address)'
   ```

2. SSL Certificate:
   ```bash
   # Create a Google-managed SSL certificate
   gcloud compute ssl-certificates create dinhnn-poc-cert \
     --domains=your-domain.example.com \
     --global
   
   # Check certificate provisioning status
   gcloud compute ssl-certificates describe dinhnn-poc-cert --global
   ```
   Note: Certificate provisioning may take 30-60 minutes.

3. Ingress Configuration (airflow/k8s/ingress.yaml):
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: "airflow-ingress"
     namespace: "airflow"
     annotations:
       kubernetes.io/ingress.global-static-ip-name: "poc-click-ip"
       ingress.gcp.kubernetes.io/pre-shared-cert: "dinhnn-poc-cert"
       kubernetes.io/ingress.class: "gce"
   spec:
     ingressClassName: "gce"
     rules:
     - http:
         paths:
         - backend:
             service:
               name: airflow-webserver
               port:
                 number: 8080
           path: /
           pathType: Prefix
   ```

4. Apply the ingress:
   ```bash
   kubectl apply -f airflow/k8s/ingress.yaml
   ```

5. Verify the setup:
   ```bash
   # Check ingress status
   kubectl get ingress -n airflow
   
   # Check backend services and health
   kubectl describe ingress airflow-ingress -n airflow
   
   # Check load balancer and backend services in GCP console
   # Navigate to: Network Services > Load Balancing
   ```

Note: The ingress configuration is automatically applied by Terraform using the kubernetes_manifest resource after the Airflow helm release is complete. If you need to make changes to the ingress configuration, you can either:
1. Modify airflow/k8s/ingress.yaml and apply it manually using kubectl
2. Update the configuration and run terraform apply to reapply the changes

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
# First, delete all workloads and PVCs in the airflow namespace
kubectl delete namespace airflow

# Delete GitHub Runner workloads
kubectl delete namespace arc-systems

# Delete Sealed Secrets
kubectl delete namespace sealed-secrets

# Verify all PVs are removed
kubectl get pv

# Then destroy the infrastructure
cd terraform
terraform destroy

# After terraform destroy completes, verify:
# 1. Check GCP Console that all resources are removed
# 2. Check for any orphaned resources:
#    - Persistent Disks
#    - Load Balancers
#    - Cloud SQL instances
#    - Static IPs
#    - Service accounts
#    - IAM bindings
```

Note: Always ensure you have backed up any important data before destroying the infrastructure.
