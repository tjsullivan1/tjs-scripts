# main.tf
locals {
}

resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  name     = random_pet.rg_name.id
  location = var.resource_group_location

  # ignore changes to tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_storage_account" "store" {
  name                     = "sa${replace(random_pet.rg_name.id, "-", "")}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = "true"
}

resource "azurerm_storage_data_lake_gen2_filesystem" "adls" {
  name               = "adls"
  storage_account_id = azurerm_storage_account.store.id
}

resource "azurerm_synapse_workspace" "synapse" {
  name                                 = "syn-${random_pet.rg_name.id}"
  resource_group_name                  = azurerm_resource_group.rg.name
  location                             = azurerm_resource_group.rg.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.adls.id
  sql_administrator_login              = "sqladminuser"
  sql_administrator_login_password     = "H@Sh1CoR3!"

  # aad_admin {
  #   login     = "AzureAD Admin"
  #   object_id = "7ec4b97f-730b-4c6e-8f86-a569b2954cf4"
  #   tenant_id = "16b3c013-d300-468d-ac64-7eda0820b6d3"
  # }

  identity {
    type = "SystemAssigned"
  }

}

resource "azurerm_api_management" "apim" {
  name                = "apim-${random_pet.rg_name.id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "My Company"
  publisher_email     = "company@terraform.io"

  sku_name = "Consumption_0"
}

resource "azurerm_cosmosdb_account" "cosmos" {
  name                  = "cdb-${random_pet.rg_name.id}"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  offer_type            = "Standard"
  analytical_storage_enabled = true

  consistency_policy {
    consistency_level = "Strong"
  }

  geo_location {
    location          = "westus"
    failover_priority = 0
  }

}

resource "azurerm_cosmosdb_sql_database" "db" {
  name                = "bulk-tutorial"
  resource_group_name = azurerm_cosmosdb_account.cosmos.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

resource "azurerm_cosmosdb_sql_container" "items" {
  name = "items"
  resource_group_name = azurerm_cosmosdb_account.cosmos.resource_group_name
  account_name        = azurerm_cosmosdb_account.cosmos.name  
  database_name = azurerm_cosmosdb_sql_database.db.name
  partition_key_path = "/pk"
  partition_key_version = 1
  throughput = 400
  analytical_storage_ttl = 1

  indexing_policy {
    indexing_mode = "none"
  }
}

resource "azurerm_synapse_firewall_rule" "fw" {
  name                 = "allowAll"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "255.255.255.255"
}


resource "azurerm_synapse_linked_service" "cosmos" {
  name                 = "cosmoslink"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  type                 = "CosmosDb"
  type_properties_json = <<JSON
  {
    "connectionString": "${azurerm_cosmosdb_account.cosmos.primary_sql_connection_string}" 
  }
  JSON

}