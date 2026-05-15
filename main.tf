# -------------------------------------------------------------------
# Empty Project Scaffold
# -------------------------------------------------------------------
#
# This repository is intentionally starting with no provisioned resources.
# Add root resources or modules here as the new project design becomes clear.

locals {
  name_suffix = "${var.workload}-${var.location}-${var.environment}"
  common_tags = merge(
    {
      workload    = var.workload
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags
  )
}
