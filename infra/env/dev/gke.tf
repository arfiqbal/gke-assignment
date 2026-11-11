
resource "google_service_account" "gke_sa" {
  account_id = "my-gke-sa"

  project = var.project_id
}


# ---------- Cluster ----------
resource "google_container_cluster" "this" {
  name     = var.cluster_name
  project  = var.project_id
  location = var.region

  enable_autopilot    = true
  deletion_protection = var.deletion_protection

  cluster_autoscaling {
    auto_provisioning_defaults {
      service_account = google_service_account.gke_sa.email
    }
  }


  network    = data.google_compute_network.vpc.id
  subnetwork = data.google_compute_subnetwork.subnet.id

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  release_channel { channel = "REGULAR" }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  fleet { project = var.project_id }

  depends_on = [google_project_service.apis]
}

# ---------- Cloud Service Mesh (managed) ----------
resource "google_gke_hub_feature" "mesh" {
  name       = "servicemesh"
  project    = var.project_id
  location   = "global"
  depends_on = [google_project_service.apis]
}

resource "google_gke_hub_feature_membership" "mesh" {
  project             = var.project_id
  location            = "global"
  feature             = google_gke_hub_feature.mesh.name
  membership          = google_container_cluster.this.fleet[0].membership
  membership_location = google_container_cluster.this.location

  mesh { management = "MANAGEMENT_AUTOMATIC" }
}
