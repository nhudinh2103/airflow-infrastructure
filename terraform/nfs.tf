resource "google_compute_disk" "airflow_disk" {
  name = "airflow-disk"
  type = "pd-ssd"
  zone = var.zone
  size = 20
}

resource "google_compute_instance" "nfs" {
  name         = "nfs"
  machine_type = "n2-standard-2"
  zone         = var.zone

  advanced_machine_features {
    visible_core_count = 1
    threads_per_core   = 2
  }

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/debian-12-bookworm-v20250212"
      size  = 10
      type  = "pd-ssd"
    }
    auto_delete = true
  }

  attached_disk {
    source      = google_compute_disk.airflow_disk.self_link
    device_name = "airflow-disk"
    mode        = "READ_WRITE"
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork
    access_config {
      network_tier = "PREMIUM"
    }
  }

  scheduling {
    preemptible                 = true
    automatic_restart           = false
    provisioning_model         = "SPOT"
    instance_termination_action = "STOP"
    on_host_maintenance        = "TERMINATE"
  }

  service_account {
    email = var.service_account
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append"
    ]
  }

  shielded_instance_config {
    enable_secure_boot          = false
    enable_vtpm                = true
    enable_integrity_monitoring = true
  }

  tags = ["nfs"]

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Install required packages
    apt-get update
    apt-get install -y nfs-kernel-server xfsprogs

    # Load XFS module
    modprobe -v xfs

    # Find the airflow-disk device
    DEVICE_ID=$(readlink -f /dev/disk/by-id/google-airflow-disk)
    if [ -z "$DEVICE_ID" ]; then
      echo "Error: Could not find airflow-disk device"
      exit 1
    fi

    # Create mount point
    mkdir -p /mnt/disks/airflow-disk

    # Format with XFS if not already formatted
    if ! blkid $DEVICE_ID | grep -q xfs; then
      mkfs.xfs $DEVICE_ID
    fi

    # Mount the disk
    mount -o discard,defaults $DEVICE_ID /mnt/disks/airflow-disk
    chmod a+w /mnt/disks/airflow-disk/

    # Update /etc/exports
    if ! grep -q "/mnt/disks/airflow-disk" /etc/exports; then
      echo "/mnt/disks/airflow-disk 10.0.0.0/8(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    fi

    # Refresh NFS exports and restart service
    exportfs -ra
    systemctl restart nfs-kernel-server

    # Get disk UUID for fstab
    UUID=$(blkid -s UUID -o value $DEVICE_ID)
    if [ -z "$UUID" ]; then
      echo "Error: Could not get disk UUID"
      exit 1
    fi

    # Update fstab if entry doesn't exist
    if ! grep -q "$UUID" /etc/fstab; then
      echo "UUID=$UUID /mnt/disks/airflow-disk xfs rw,discard,x-systemd.growfs 0 1" >> /etc/fstab
    fi

    # Create and set permissions for Airflow and GitHub Runners directories
    mkdir -p /mnt/disks/airflow-disk/airflow
    mkdir -p /mnt/disks/airflow-disk/airflow/dags
    mkdir -p /mnt/disks/airflow-disk/airflow/logs
    
    chmod -R 775 /mnt/disks/airflow-disk/airflow
    chown -R 50000:50000 /mnt/disks/airflow-disk/airflow

    mkdir -p /mnt/disks/airflow-disk/github-runners
    chown -R 50000:50000 /mnt/disks/airflow-disk/github-runners
  EOF

  depends_on = [google_compute_disk.airflow_disk]
}
