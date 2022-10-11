resource "azurerm_storage_account" "tjs" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  network_rules {
    default_action = "Deny"
    ip_rules       = ["73.65.80.95"]
  }

  tags = {
    environment = "staging"
  }
}