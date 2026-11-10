# ---------- Workload Identity Federation for GitHub Actions (keyless) ----------

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = var.wif_pool_id
  display_name              = "GitHub Actions"
  description               = "Federated identities from GitHub Actions OIDC tokens"

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = var.wif_provider_id
  display_name                       = "GitHub OIDC"

  # Map claims from the GitHub token to Google attributes
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  # Only tokens issued for THIS repository are accepted at all.
  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# ---------- Service account that GitHub Actions impersonates ----------

resource "google_service_account" "github_ci" {
  project      = var.project_id
  account_id   = var.ci_service_account_id
  display_name = "GitHub Actions CI"

  depends_on = [google_project_service.apis]
}

# Allow identities from the pool (restricted to the repo) to impersonate the service account
resource "google_service_account_iam_member" "github_wif" {
  service_account_id = google_service_account.github_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}
