variable "project_id" {
  description = "The project ID to host the cluster in"
  type        = string
}

variable "cluster_name" {
  description = "The name of the cluster"
  type        = string
  default     = "dinhnnpoc-airflow-test-cluster"
}

variable "zone" {
  description = "The zone to host the cluster in"
  type        = string
  default     = "asia-southeast1-c"
}

variable "network" {
  description = "The VPC network to host the cluster in"
  type        = string
}

variable "subnetwork" {
  description = "The subnetwork to host the cluster in"
  type        = string
}

variable "ip_range_pods" {
  description = "The secondary ip range to use for pods"
  type        = string
}

variable "ip_range_services" {
  description = "The secondary ip range to use for services"
  type        = string
}

variable "service_account" {
  description = "The service account to use for the cluster"
  type        = string
}

variable "authorized_ipv4_cidr" {
  description = "The CIDR block for master authorized networks"
  type        = string
  default     = "42.119.80.24/32"
}

variable "nfs_path_logs" {
  description = "NFS path for Airflow logs"
  type        = string
  default     = "/mnt/disks/airflow-disk/airflow/logs"
}

variable "nfs_path_dags" {
  description = "NFS path for Airflow DAGs"
  type        = string
  default     = "/mnt/disks/airflow-disk/airflow/dags"
}

variable "db_instance_name" {
  description = "The name of the Cloud SQL instance"
  type        = string
  default     = "airflow-db"
}

variable "db_password" {
  description = "The password for the Cloud SQL postgres user"
  type        = string
  sensitive   = true
}

variable "db_region" {
  description = "The region for the Cloud SQL instance"
  type        = string
  default     = "asia-southeast1"
}

variable "airflow_repository" {
  description = "Repository for Airflow images"
  type        = string
  default     = "asia.gcr.io/personal-project-447516/airflow"
}

variable "default_storage_class" {
  description = "Default storage class for kubernetes cluster"
  type        = string
  default     = "standard-rwo"
}

variable "sealed_secret_psycopg2_encrypted_connection" {
  description = "Url for connect to metadata db using pyscopg2"
  type        = string
  default     = "AgAYs7paECt0ftH/8RRqQBqnzx+jT4oXj0cddqvzAqjF89Hf4w0PxNsiqFysC+Ra88ZPrq5oSmoRCgAHgBZhATvK27Yymx/2w72WPrYbssx21H/+5GBi5RXe6e4YbY08svGgfDIM8zdvDxMGIFY0wH4udkZEU9iCYc0e3nD9U/R+f458zmw0TN4H9zCEqZpAmlY18renajRrZOi4tg9k1dAecS8/cltgcp5vde8xxronsFB3wDRes+vzCcRzUUlcdUioOeDq3WKflUotdNx9eR6IYJremddsFty7rIxmFWxeB+u6fYVj/OajNlk6z7lVDydg12BzX2aApj9Wx2joDPuHotpzVzFP5HfrfQNf1S7uIKZ5zDlAV4ky8Z222CSOOf7LRZGMiMHYZVuAK2wxR+0hnI9FgtG3p0SocVuxbORgL95puEgJdbXAE1uUrCNOLYHFPjZvKGcj50i8WsovVf31hk612yaJ+blJjDpEp3uZtj/SIK49HhISS5v/vTuL6NJxslGQXEmucnuG+onRBIm1dDuZzlmddXZlDSopSQ4zwlqgBXaXOhWEejKYA2zAZlPpsCkl8fEInmn+v9g1rOBXO0MsEzRVqfdBhD5kI2m0uapGZSxuAq5bA95rB0KSACKhgBw0/4NqFUxLZakMq5gwESRGTI7E2GX7G2zd1oVueLPFvQUUq0uHFWzd8JdrB+hJrE8OAKxvOvnIcK1dzrba/fJvbEFnWcxYq/+wA8pP6lQlbBqMdrFfE/d3wBqU4RDos5b/PzXhUZAZa5gEq0h5Vd6EO6kZExQotyj+BTEv"
}
