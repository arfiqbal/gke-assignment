project_id             = "stable-electron-506610-c6"
region                 = "asia-south1"
cluster_name           = "autopilot-asm"
create_nat             = true
neg_name               = "ingress-443"
neg_zones              = ["asia-south1-b", "asia-south1-c"]
proxy_only_subnet_cidr = "192.168.0.0/24"
subnetwork_name        = "default"
enable_lb              = true
gateway_backend_port   = 443

wif_pool_id           = "github-pool"
wif_provider_id       = "github-oidc"
github_repository     = "arfiqbal/gke-assignment"
ci_service_account_id = "github-ci"
ci_roles = [
  "roles/container.developer",     # deploy to the GKE cluster
  "roles/artifactregistry.writer", # push container images
]
