# Note: Google Container Registry (gcr.io) is deprecated; Artifact Registry is its replacement.

resource "google_artifact_registry_repository" "images" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_registry_repo_id
  format        = "DOCKER"
  description   = "Container images for the build-info service"

  cleanup_policy_dry_run = false

  # Remove untagged leftovers
  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "${var.untagged_retention_days * 86400}s"
    }
  }

  # ...but always keep the most recent versions (KEEP wins over DELETE)
  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = var.keep_recent_versions
    }
  }

  depends_on = [google_project_service.apis]
}

# ---------- IAM on the repository (least privilege, scoped to this repo only) ----------

# # GitHub Actions can push images
# resource "google_artifact_registry_repository_iam_member" "ci_writer" {
#   project    = var.project_id
#   location   = google_artifact_registry_repository.images.location
#   repository = google_artifact_registry_repository.images.name
#   role       = "roles/artifactregistry.writer"
#   member     = "serviceAccount:${google_service_account.github_ci.email}"
# }

# GKE nodes can pull images (only if a node service account is provided)
resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  count = var.gke_node_service_account_email == null ? 0 : 1

  project    = var.project_id
  location   = google_artifact_registry_repository.images.location
  repository = google_artifact_registry_repository.images.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.gke_node_service_account_email}"
}
