variable "project_id" {
  description = "GCP project ID that hosts the registry and the identity pool."
  type        = string
}

variable "region" {
  description = "Region for the Artifact Registry repository (e.g. asia-south1)."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to authenticate, in OWNER/REPO form."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must look like OWNER/REPO."
  }
}

variable "artifact_registry_repo_id" {
  description = "Artifact Registry repository name."
  type        = string
  default     = "build-info"
}

variable "wif_pool_id" {
  description = "Workload Identity Pool ID."
  type        = string
  default     = "github-pool"
}

variable "wif_provider_id" {
  description = "Workload Identity Pool Provider ID."
  type        = string
  default     = "github-provider"
}

variable "ci_service_account_id" {
  description = "Account ID of the service account GitHub Actions impersonates."
  type        = string
  default     = "github-ci"
}

variable "gke_node_service_account_email" {
  description = "Service account used by GKE nodes. If set, it gets read access to the registry so nodes can pull images. Leave null to skip."
  type        = string
  default     = null
}

variable "untagged_retention_days" {
  description = "Delete untagged images older than this many days."
  type        = number
  default     = 7
}

variable "keep_recent_versions" {
  description = "Always keep at least this many most recent image versions."
  type        = number
  default     = 20
}
