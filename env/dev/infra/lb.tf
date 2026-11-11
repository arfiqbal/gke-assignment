# ---------------------------------------------------------
# 1. Proxy-only subnet
# ---------------------------------------------------------

resource "google_compute_subnetwork" "proxy_only" {
  name          = "${var.cluster_name}-proxy-only"
  project       = var.project_id
  region        = var.region
  network       = data.google_compute_network.vpc.id
  ip_cidr_range = var.proxy_only_subnet_cidr

  purpose = "REGIONAL_MANAGED_PROXY"
  role    = "ACTIVE"
}

# ---------------------------------------------------------
# 2. Data source for backend target subnetwork
# ---------------------------------------------------------

data "google_compute_subnetwork" "lb" {
  name    = var.subnetwork_name
  region  = var.region
  project = var.project_id
}

# ---------------------------------------------------------
# 3. Regional internal static IP (Internal TCP Proxy VIP)
# ---------------------------------------------------------

resource "google_compute_address" "lb" {
  name         = "${var.cluster_name}-gw-ip"
  project      = var.project_id
  region       = var.region
  address_type = "INTERNAL"
  purpose      = "SHARED_LOADBALANCER_VIP"
  subnetwork   = data.google_compute_subnetwork.lb.id

  depends_on = [
    google_project_service.apis
  ]
}

# ---------------------------------------------------------
# 4. Firewall - Allow proxy-only subnet and health checks
# ---------------------------------------------------------

resource "google_compute_firewall" "proxy_to_gateway" {
  name      = "${var.cluster_name}-allow-proxy-to-gateway"
  project   = var.project_id
  network   = data.google_compute_network.vpc.id
  direction = "INGRESS"

  source_ranges = [
    var.proxy_only_subnet_cidr
  ]

  allow {
    protocol = "tcp"
    ports    = [tostring(var.gateway_backend_port), "8443", "15021"]
  }
}

resource "google_compute_firewall" "health_check" {
  name      = "${var.cluster_name}-allow-health-check"
  project   = var.project_id
  network   = data.google_compute_network.vpc.id
  direction = "INGRESS"

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]

  allow {
    protocol = "tcp"
    ports    = ["15021"]
  }
}

# ---------------------------------------------------------
# 5. GKE-managed zonal NEG lookup
# ---------------------------------------------------------

data "google_compute_network_endpoint_group" "gw" {
  for_each = var.enable_lb ? toset(var.neg_zones) : toset([])

  name    = var.neg_name
  zone    = each.key
  project = var.project_id
}

# ---------------------------------------------------------
# 6. Regional health check
# ---------------------------------------------------------

resource "google_compute_region_health_check" "gw" {
  count   = var.enable_lb ? 1 : 0
  name    = "${var.cluster_name}-gw-hc"
  project = var.project_id
  region  = var.region

  http_health_check {
    port         = 15021
    request_path = "/healthz/ready"
  }
}

# ---------------------------------------------------------
# 7. Regional backend service - NEG backends
# ---------------------------------------------------------

resource "google_compute_region_backend_service" "gw" {
  count   = var.enable_lb ? 1 : 0
  name    = "${var.cluster_name}-gw-be"
  project = var.project_id
  region  = var.region

  protocol              = "TCP"
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = 30

  health_checks = [
    google_compute_region_health_check.gw[0].id
  ]

  dynamic "backend" {
    for_each = data.google_compute_network_endpoint_group.gw

    content {
      group                        = backend.value.id
      balancing_mode               = "CONNECTION"
      max_connections_per_endpoint = 1000
      capacity_scaler              = 1.0
    }
  }

  depends_on = [
    google_compute_firewall.proxy_to_gateway,
    google_compute_firewall.health_check
  ]
}

# ---------------------------------------------------------
# 8. Regional target TCP proxy
# ---------------------------------------------------------

resource "google_compute_region_target_tcp_proxy" "gw" {
  count   = var.enable_lb ? 1 : 0
  name    = "${var.cluster_name}-gw-proxy"
  project = var.project_id
  region  = var.region

  backend_service = google_compute_region_backend_service.gw[0].id
  proxy_header    = "NONE"
}

# ---------------------------------------------------------
# 9. Regional internal forwarding rule
# ---------------------------------------------------------

resource "google_compute_forwarding_rule" "gw" {
  count   = var.enable_lb ? 1 : 0
  name    = "${var.cluster_name}-gw-fr"
  project = var.project_id
  region  = var.region

  load_balancing_scheme = "INTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "443"

  ip_address = google_compute_address.lb.id

  network    = data.google_compute_network.vpc.id
  subnetwork = data.google_compute_subnetwork.lb.id

  target = google_compute_region_target_tcp_proxy.gw[0].id

  depends_on = [
    google_compute_subnetwork.proxy_only
  ]
}
