# ---------- Outputs for the GitHub workflow ----------

output "workload_identity_provider" {
  description = "Use as 'workload_identity_provider' in google-github-actions/auth"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "Use as 'service_account' in google-github-actions/auth"
  value       = google_service_account.github_ci.email
}
