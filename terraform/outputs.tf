output "nfs_server_ip" {
  description = "Internal IP address of the NFS server"
  value       = google_compute_instance.nfs.network_interface[0].network_ip
}

output "nfs_server_public_ip" {
  description = "External IP address of the NFS server"
  value       = google_compute_instance.nfs.network_interface[0].access_config[0].nat_ip
}

output "gke_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.gke.endpoint
  sensitive   = true
}

output "kubectl_command" {
  description = "Command to configure kubectl with the GKE cluster"
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --zone ${var.zone} --project ${var.project_id}"
}
