terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 8.0"
    }
  }

  # Recommended: keep state in a GCS bucket (create the bucket once, outside this config).
  # backend "gcs" {
  #   bucket = "YOUR-TFSTATE-BUCKET"
  #   prefix = "github-ci"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
