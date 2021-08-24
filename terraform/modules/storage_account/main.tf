resource "azurerm_storage_account" "tjs" {
  name                     = "sa${lower(var.disambiguation)}${var.random_string}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "staging"
  }
}