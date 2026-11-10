data "google_compute_network" "vpc" {
  name    = var.network_name
  project = var.project_id
}

data "google_compute_subnetwork" "subnet" {
  name    = var.subnetwork_name
  region  = var.region
  project = var.project_id
}

resource "google_compute_router" "router" {
  count   = var.create_nat ? 1 : 0
  name    = "${var.cluster_name}-router"
  project = var.project_id
  region  = var.region
  network = data.google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  count                              = var.create_nat ? 1 : 0
  name                               = "${var.cluster_name}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.router[0].name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
