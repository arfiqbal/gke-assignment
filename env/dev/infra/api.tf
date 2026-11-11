resource "google_project_service" "apis" {
  for_each = toset([
    "container.googleapis.com", "gkehub.googleapis.com",
    "mesh.googleapis.com", "meshconfig.googleapis.com",
    "meshca.googleapis.com", "compute.googleapis.com",
    "dns.googleapis.com", "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}
