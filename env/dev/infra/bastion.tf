resource "google_compute_instance" "iap_bastion" {
  name         = "iap-bastion"
  machine_type = "e2-micro"
  zone         = "asia-south1-a"
  project      = var.project_id

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network    = data.google_compute_network.vpc.id
    subnetwork = "default" # Or reference your specific subnetwork
  }
}

# Required firewall rule to allow Google IAP proxy to reach SSH (port 22) on your bastion
resource "google_compute_firewall" "allow_iap_ssh" {
  name      = "${var.cluster_name}-allow-iap-ssh"
  project   = var.project_id
  network   = data.google_compute_network.vpc.id
  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"] # Google's official IAP TCP forwarding range

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}


# gcloud compute ssh iap-bastion \
#     --zone=asia-south1-a \
#     --tunnel-through-iap \
#     -- -L 8443:10.160.0.15:443 -N
