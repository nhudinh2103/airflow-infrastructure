# Cloud SQL instance
resource "google_sql_database_instance" "airflow" {
  name             = var.db_instance_name
  database_version = "POSTGRES_17"
  region           = var.db_region
  project          = var.project_id

  settings {
    tier              = "db-custom-1-3840"
    availability_type = "ZONAL"
    disk_size         = 10
    disk_type        = "PD_SSD"
    
    backup_configuration {
      enabled = true
      point_in_time_recovery_enabled = true
    }

    ip_configuration {
      ipv4_enabled = true
      # For production, you might want to use private IP and authorized networks
      # private_network = var.network
      # authorized_networks {
      #   name  = "allowed-ip"
      #   value = var.authorized_ipv4_cidr
      # }
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  deletion_protection = true # Set to false if you want to allow deletion
}

# Create the postgres user
resource "google_sql_user" "postgres" {
  name     = "postgres"
  instance = google_sql_database_instance.airflow.name
  password = var.db_password
  project  = var.project_id
}

# Create the airflow database
resource "google_sql_database" "airflow" {
  name     = "airflow"
  instance = google_sql_database_instance.airflow.name
  project  = var.project_id
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

output "database_public_ip" {
  description = "The public IP address of the database instance"
  value       = google_sql_database_instance.airflow.public_ip_address
}
