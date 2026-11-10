# resource "google_dns_managed_zone" "this" {
#   count      = var.create_dns_zone ? 1 : 0
#   name       = replace(trimsuffix(var.dns_zone_dns_name, "."), ".", "-")
#   project    = var.project_id
#   dns_name   = var.dns_zone_dns_name
#   depends_on = [google_project_service.apis]
# }

# locals {
#   dns_zone_name = var.create_dns_zone ? google_dns_managed_zone.this[0].name : var.existing_dns_zone_name
# }

# resource "google_dns_record_set" "app" {
#   project      = var.project_id
#   managed_zone = local.dns_zone_name
#   name         = "${var.hostname}."
#   type         = "A"
#   ttl          = 300
#   rrdatas      = [google_compute_global_address.lb.address]
# }
