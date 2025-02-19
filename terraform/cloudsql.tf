data "google_compute_network" "default" {
  name    = var.network
  project = var.project_id
}

data "google_compute_subnetwork" "default" {
  name    = var.subnetwork
  region  = var.db_region
  project = var.project_id
}

resource "google_compute_global_address" "private_ip_range" {
  provider = google-beta

  name          = "airflow-internal"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = data.google_compute_network.default.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = google-beta
  network                 = data.google_compute_network.default.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

# Cloud SQL instance
resource "google_sql_database_instance" "airflow" {
  name             = var.db_instance_name
  database_version = "POSTGRES_17"
  region           = var.db_region
  project          = var.project_id

  depends_on = [
    google_service_networking_connection.private_vpc_connection
  ]

  settings {
    tier              = "db-custom-1-3840"
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type        = "PD_SSD"
    
    backup_configuration {
      enabled = true
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled                                  = true
      private_network                               = data.google_compute_network.default.id
      allocated_ip_range                            = google_compute_global_address.private_ip_range.name
      enable_private_path_for_google_cloud_services = true
      authorized_networks {
        name  = "allowed-ip"
        value = var.authorized_ipv4_cidr
      }
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  deletion_protection = false # Temporarily set to false to allow recreation
}

# Create the postgres user
resource "google_sql_user" "postgres" {
  name     = "postgres"
  instance = google_sql_database_instance.airflow.name
  password = var.db_password
  project  = var.project_id

  depends_on = [google_sql_database_instance.airflow]
}

# Create the airflow database
resource "google_sql_database" "airflow" {
  name     = "airflow"
  instance = google_sql_database_instance.airflow.name
  project  = var.project_id

  depends_on = [google_sql_database_instance.airflow]
}

# Outputs for use in other resources
output "database_instance_name" {
  description = "The name of the database instance"
  value       = google_sql_database_instance.airflow.name
}

output "database_connection_name" {
  description = "The connection name of the database instance"
  value       = google_sql_database_instance.airflow.connection_name
}

provider "google-beta" {
  region = var.db_region
  zone   = var.zone
}
