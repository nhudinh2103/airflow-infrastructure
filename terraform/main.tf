terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "google" {
  project = var.project_id
  zone    = var.zone
}

# Configure kubernetes provider with Oauth2 access token.
data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${module.gke.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(module.gke.ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${module.gke.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(module.gke.ca_certificate)
  }
}

# GKE cluster
module "gke" {
  source                     = "terraform-google-modules/kubernetes-engine/google"
  project_id                 = var.project_id
  name                       = var.cluster_name
  regional                   = false
  zones                      = [var.zone]
  network                    = var.network
  subnetwork                = var.subnetwork
  ip_range_pods             = var.ip_range_pods
  ip_range_services         = var.ip_range_services
  release_channel           = "regular"
  cluster_resource_labels   = { "cost-allocation" = "true" }
  enable_cost_allocation    = true
  
  # Networking
  datapath_provider         = "ADVANCED_DATAPATH"  # Dataplane V2
  enable_ip_alias          = true
  enable_intranode_visibility = false
  enable_multi_networking  = true
  dns_cache               = true
  enable_vertical_pod_autoscaling = true
  
  # Security
  enable_shielded_nodes    = true
  enable_binary_authorization = false
  security_posture_mode    = "STANDARD"
  workload_vulnerability_scanning_mode = "STANDARD"
  enable_gcfs             = true  # Image streaming
  enable_managed_prometheus = true
  workload_pool          = "${var.project_id}.svc.id.goog"
  
  # Master authorized networks
  master_authorized_networks = [
    {
      cidr_block   = var.authorized_ipv4_cidr
      display_name = "Authorized Network"
    }
  ]

  # Node pool configuration
  remove_default_node_pool  = true
  initial_node_count       = 1

  node_pools = [
    {
      name               = "default-pool"
      machine_type       = "n2d-standard-2"
      min_count         = 0
      max_count         = 1
      spot              = true
      disk_size_gb      = 20
      disk_type         = "pd-ssd"
      image_type        = "UBUNTU_CONTAINERD"
      enable_gcfs       = true
      auto_repair       = true
      auto_upgrade      = true
      service_account   = var.service_account
      
      # Upgrade settings
      max_surge         = 1
      max_unavailable   = 0
      
      # Autoscaling profile
      autoscaling_profile = "OPTIMIZE_UTILIZATION"
      
      # Shielded instance config
      shielded_instance_config = {
        enable_secure_boot          = true
        enable_integrity_monitoring = true
      }
    }
  ]

  # Addons
  network_policy             = false
  http_load_balancing       = true
  horizontal_pod_autoscaling = true
  filestore_csi_driver      = true
  gce_persistent_disk_csi_driver = true
  config_connector          = true
  node_local_dns           = true
  gcp_filestore_csi_driver = true
}

# Install Sealed Secrets
resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  chart      = "./sealed-secrets"
  namespace  = "kube-system"
  depends_on = [module.gke]

  set {
    name  = "fullnameOverride"
    value = "sealed-secrets-controller"
  }
}

# Install GitHub Runner Controller
resource "kubernetes_namespace" "github_runner" {
  metadata {
    name = "github-runner"
  }
  depends_on = [module.gke]
}

resource "helm_release" "github_runner_controller" {
  name       = "github-runner-controller"
  chart      = "./github-runner/gha-runner-scale-set-controller"
  namespace  = kubernetes_namespace.github_runner.metadata[0].name
  depends_on = [helm_release.sealed_secrets]
}

resource "helm_release" "github_runner_scale_set" {
  name       = "github-runner-scale-set"
  chart      = "./github-runner/gha-runner-scale-set"
  namespace  = kubernetes_namespace.github_runner.metadata[0].name
  depends_on = [helm_release.github_runner_controller]

  values = [
    file("./github-runner/gha-runner-scale-set/values-airflow-gke.yaml")
  ]
}

# Install Airflow
resource "kubernetes_namespace" "airflow" {
  metadata {
    name = "airflow"
  }
  depends_on = [module.gke, google_compute_instance.nfs]
}

# Create NFS PV/PVCs for Airflow
resource "kubernetes_persistent_volume" "airflow_logs" {
  metadata {
    name = "airflow-logs"
  }
  spec {
    capacity = {
      storage = "10Gi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      nfs {
        path   = var.nfs_path_logs
        server = google_compute_instance.nfs.network_interface[0].network_ip
      }
    }
  }
  depends_on = [module.gke]
}

resource "kubernetes_persistent_volume" "airflow_dags" {
  metadata {
    name = "airflow-dags"
  }
  spec {
    capacity = {
      storage = "10Gi"
    }
    access_modes = ["ReadWriteMany"]
    persistent_volume_source {
      nfs {
        path   = var.nfs_path_dags
        server = google_compute_instance.nfs.network_interface[0].network_ip
      }
    }
  }
  depends_on = [module.gke]
}

resource "kubernetes_persistent_volume_claim" "airflow_logs" {
  metadata {
    name      = "airflow-logs"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.airflow_logs.metadata[0].name
  }
}

resource "kubernetes_persistent_volume_claim" "airflow_dags" {
  metadata {
    name      = "airflow-dags"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }
  spec {
    access_modes = ["ReadWriteMany"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
    volume_name = kubernetes_persistent_volume.airflow_dags.metadata[0].name
  }
}

resource "helm_release" "airflow" {
  name       = "airflow"
  chart      = "./airflow/helm"
  namespace  = kubernetes_namespace.airflow.metadata[0].name
  depends_on = [
    helm_release.sealed_secrets,
    kubernetes_persistent_volume_claim.airflow_logs,
    kubernetes_persistent_volume_claim.airflow_dags
  ]

  values = [
    file("./airflow/helm/values-gke.yaml")
  ]
}
