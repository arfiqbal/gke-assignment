variable "project_id" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "create_nat" {
  type    = bool
  default = true
}

variable "deletion_protection" {
  type    = bool
  default = false # set true for production
}

variable "network_name" {
  type    = string
  default = "default"
}

variable "subnetwork_name" {
  type    = string
  default = "default"
}
variable "master_ipv4_cidr_block" {
  type        = string
  default     = "172.16.0.0/28"
  description = "Private /28 for the GKE control plane. Must not overlap any range in the VPC or peered networks."
}
variable "pods_range_name" {
  type    = string
  default = null
}

variable "services_range_name" {
  type    = string
  default = null
}

variable "release_channel" {
  type    = string
  default = "REGULAR"
}

# Load balancer / DNS (only if you use those files)
variable "enable_lb" {
  type    = bool
  default = false
}

variable "neg_name" {
  type    = string
  default = "ingress-443"
}

variable "neg_zones" {
  type    = list(string)
  default = []
}

variable "hostname" {
  type    = string
  default = null
}

variable "waf_cname_target" {
  type    = string
  default = null
}

variable "allowed_source_ranges" {
  type    = list(string)
  default = []
}

variable "proxy_only_subnet_cidr" {
  type = string
}

variable "gateway_backend_port" {
  description = "Actual port exposed by the GKE NEG endpoints"
  type        = number
  default     = 443
}

