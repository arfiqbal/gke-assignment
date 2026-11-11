# GCS bucket
resource "google_storage_bucket" "demo" {
  name                        = var.bucket_name
  location                    = var.region
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }
}

# Google service account the pod will act as
resource "google_service_account" "app" {
  account_id   = var.gsa_name
  display_name = "build-info workload identity SA"
}

# GSA -> objectAdmin on this bucket only
resource "google_storage_bucket_iam_member" "app_object_admin" {
  bucket = google_storage_bucket.demo.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.app.email}"
}

# KSA -> GSA binding (Workload Identity)
resource "google_service_account_iam_member" "wi_binding" {
  service_account_id = google_service_account.app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.ksa_name}]"
}