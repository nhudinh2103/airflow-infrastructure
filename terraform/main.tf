terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.20.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.35.1"
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
  release_channel           = "REGULAR"
  cluster_resource_labels   = { "cost-allocation" = "true" }
  enable_cost_allocation    = true
  
  # Networking
  datapath_provider         = "ADVANCED_DATAPATH"  # Dataplane V2
  enable_intranode_visibility = false
  dns_cache               = true
  enable_vertical_pod_autoscaling = true
  
  # Security
  enable_shielded_nodes    = true
  enable_binary_authorization = false
  security_posture_mode    = "BASIC"
  enable_gcfs             = true  # Image streaming
  
  # Workload Identity
  identity_namespace       = "${var.project_id}.svc.id.goog"
  
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
      name                 = "default"
      machine_type         = "n2d-standard-4"
      node_locations       = var.zone
      autoscaling          = false
      local_ssd_count      = 0
      disk_size_gb         = 20
      disk_type            = "pd-ssd"
      image_type           = "UBUNTU_CONTAINERD"
      auto_repair          = true
      auto_upgrade         = true
      spot                = true
      initial_node_count  = 1
      service_account     = var.service_account
    }
  ]

  node_pools_oauth_scopes = {
    default-pool = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  node_pools_labels = {
    default-pool = {}
  }

  node_pools_metadata = {
    default-pool = {}
  }

  node_pools_taints = {
    default-pool = []
  }

  node_pools_tags = {
    default-pool = []
  }

  # Addons
  network_policy             = false
  http_load_balancing       = true
  horizontal_pod_autoscaling = true
  filestore_csi_driver      = true
  config_connector          = true
}

# Install Sealed Secrets
resource "kubernetes_namespace" "sealed_secrets" {
  metadata {
    name = "sealed-secrets"
  }
  depends_on = [module.gke]
}

resource "helm_release" "sealed_secrets" {
  name       = "sealed-secrets"
  chart      = "../sealed-secrets"
  namespace  = kubernetes_namespace.sealed_secrets.metadata[0].name
  depends_on = [kubernetes_namespace.sealed_secrets]

  set {
    name  = "fullnameOverride"
    value = "sealed-secrets-controller"
  }
}

# Install GitHub Runner Controller
resource "kubernetes_namespace" "arc_systems" {
  metadata {
    name = "arc-systems"
  }
  depends_on = [module.gke]
}

resource "helm_release" "arc" {
  name       = "arc"
  chart      = "../github-runner/gha-runner-scale-set-controller"
  namespace  = kubernetes_namespace.arc_systems.metadata[0].name
  depends_on = [helm_release.sealed_secrets]
}

resource "helm_release" "arc_runner_set" {
  name       = "arc-runner-set"
  chart      = "../github-runner/gha-runner-scale-set"
  namespace  = kubernetes_namespace.airflow.metadata[0].name
  depends_on = [helm_release.arc, kubernetes_namespace.airflow]

  values = [
    file("../github-runner/gha-runner-scale-set/values-airflow-gke.yaml")
  ]
}

# Install Airflow
resource "kubernetes_namespace" "airflow" {
  metadata {
    name = "airflow"
  }
  depends_on = [module.gke, google_compute_instance.nfs]
}

# Create Kubernetes Service Account for Airflow
  resource "kubernetes_service_account" "airflow_ksa" {
  metadata {
    name = "ksa-rancher-provision-gke"
    namespace = kubernetes_namespace.airflow.metadata[0].name
    annotations = {
    "iam.gke.io/gcp-service-account" = var.service_account
    }
  }
  depends_on = [kubernetes_namespace.airflow]
}

# Allow KSA to impersonate GSA
resource "google_service_account_iam_member" "workload_identity_binding" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.service_account}"
  role = "roles/iam.workloadIdentityUser"
  member = "serviceAccount:${var.project_id}.svc.id.goog[${kubernetes_namespace.airflow.metadata[0].name}/ksa-rancher-provision-gke]"
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
    name      = "airflow-logs-nfs-pvc"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }
  depends_on = [kubernetes_namespace.airflow]
  spec {
    access_modes = ["ReadWriteMany"]
    storage_class_name = ""
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
    name      = "airflow-dags-nfs-pvc"
    namespace = kubernetes_namespace.airflow.metadata[0].name
  }
  depends_on = [kubernetes_namespace.airflow]
  spec {
    access_modes = ["ReadWriteMany"]
    storage_class_name = ""
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
  chart      = "../airflow/helm"
  namespace  = kubernetes_namespace.airflow.metadata[0].name
  depends_on = [
    helm_release.sealed_secrets,
    kubernetes_persistent_volume_claim.airflow_logs,
    kubernetes_persistent_volume_claim.airflow_dags,
    kubernetes_namespace.airflow,
    google_sql_database_instance.airflow,
    sealedsecret_raw_secrets.airflow-metadata-secret
  ]

  values = [
    file("../airflow/helm/values-gke.yaml")
  ]

  set {
    name  = "defaultAirflowRepository"
    value = var.airflow_repository
  }
  
  set {
    name  = "images.airflow.repository"
    value = var.airflow_repository
  }

  set {
    name  = "serviceAccount.annotations.iam\\.gke\\.io/gcp-service-account"
    value = var.service_account
  }

  set {
    name  = "redis.persistence.storageClassName"
    value = var.default_storage_class
  }

}

# Apply Airflow Ingress
resource "kubernetes_manifest" "airflow_ingress" {
  manifest = yamldecode(file("../airflow/k8s/ingress.yaml"))
  depends_on = [helm_release.airflow]
}
