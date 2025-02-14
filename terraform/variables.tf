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
