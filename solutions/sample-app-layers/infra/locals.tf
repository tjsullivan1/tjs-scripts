# Local Values
# Define computed values and complex expressions


locals {
  # Common naming convention
  name_prefix = "${var.project_prefix}-${var.project_stage}"

  # Resource naming
  resource_group_name  = "rg-${local.name_prefix}-${random_string.suffix.result}"
  sql_server_name         = "sqlsrv-${local.name_prefix}-${random_string.suffix.result}"
  sql_db_name      = "db-${local.name_prefix}"
  storage_account_name = "st${replace(lower(local.name_prefix), "-", "")}${random_string.suffix.result}"
  key_vault_name       = "kv-${substr(local.name_prefix, 0, 14)}-${random_string.suffix.result}"
  web_app_name_prefix  = "${local.name_prefix}-${random_string.suffix.result}"
  vnet_name            = "vnet-${local.name_prefix}-${random_string.suffix.result}"

}

# Random string for unique resource names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}