terraform {
  required_version = "~> 1.0.0"
  required_providers {
    azurerm = {
      source  = "registry.terraform.io/hashicorp/azurerm"
      version = "> 2.72.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = false
  features {}
}

data "azurerm_subscription" "primary" {}

data "azurerm_client_config" "current" {}

locals {
  key_vault_id = "/subscriptions/8b63fe10-d76a-4f8f-81ce-7a5a8b911779/resourceGroups/rg-shared-services/providers/Microsoft.KeyVault/vaults/tjs-kv-1"
}

resource "azurerm_resource_group" "tjssynapse" {
  name     = "rg-tjssynapse"
  location = "East US"
}

resource "azurerm_storage_account" "tjssynapse" {
  name                     = "tjssynapsestorageacc"
  resource_group_name      = azurerm_resource_group.tjssynapse.name
  location                 = azurerm_resource_group.tjssynapse.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"
}

resource "azurerm_storage_data_lake_gen2_filesystem" "tjssynapse" {
  name               = "tjssynapse"
  storage_account_id = azurerm_storage_account.tjssynapse.id
}

resource "azurerm_synapse_workspace" "tjssynapse" {
  name                                 = "tjssynapse"
  resource_group_name                  = azurerm_resource_group.tjssynapse.name
  location                             = azurerm_resource_group.tjssynapse.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.tjssynapse.id
  sql_administrator_login              = "sqladminuser"
  sql_administrator_login_password     = "H@Sh1CoR3!"

  customer_managed_key_versionless_id = azurerm_key_vault_key.tjssynapse.versionless_id
}

resource "azurerm_key_vault_access_policy" "tjssynapse" {
  key_vault_id = local.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_synapse_workspace.tjssynapse.identity.0.principal_id

  key_permissions = [
    "Get",
    "WrapKey",
    "UnwrapKey",
  ]
}

resource "azurerm_key_vault_key" "tjssynapse" {
  name         = "tjssynapse-key"
  key_vault_id = local.key_vault_id
  key_type     = "RSA"
  key_size     = 2048

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]
}