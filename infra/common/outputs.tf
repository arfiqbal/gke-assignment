output "registry_url" {
  description = "Base URL of the Docker repository."
  value       = "${google_artifact_registry_repository.images.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.images.repository_id}"
}

output "workload_identity_provider" {
  description = "Value for the WIF_PROVIDER GitHub variable."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "ci_service_account_email" {
  description = "Value for the WIF_SERVICE_ACCOUNT GitHub variable."
  value       = google_service_account.github_ci.email
}

output "github_actions_variables" {
  description = "Everything the workflow needs, ready to paste into GitHub repository variables."
  value = {
    GCP_PROJECT_ID      = var.project_id
    GCP_REGION          = var.region
    AR_REPO             = google_artifact_registry_repository.images.repository_id
    WIF_PROVIDER        = google_iam_workload_identity_pool_provider.github.name
    WIF_SERVICE_ACCOUNT = google_service_account.github_ci.email
  }
}
