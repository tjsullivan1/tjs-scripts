output "cosmosdb_account_id" {
  description = "The ID of the CosmosDB account."
  value       = azurerm_cosmosdb_account.main.id
}

output "cosmosdb_account_name" {
  description = "The name of the CosmosDB account."
  value       = azurerm_cosmosdb_account.main.name
}

output "cosmosdb_account_endpoint" {
  description = "The endpoint used to connect to the CosmosDB account."
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "cosmosdb_account_read_endpoints" {
  description = "A list of read endpoints available for this CosmosDB account."
  value       = azurerm_cosmosdb_account.main.read_endpoints
}

output "cosmosdb_account_write_endpoints" {
  description = "A list of write endpoints available for this CosmosDB account."
  value       = azurerm_cosmosdb_account.main.write_endpoints
}

output "cosmosdb_account_primary_key" {
  description = "The primary key for the CosmosDB account."
  value       = azurerm_cosmosdb_account.main.primary_key
  sensitive   = true
}

output "cosmosdb_account_secondary_key" {
  description = "The secondary key for the CosmosDB account."
  value       = azurerm_cosmosdb_account.main.secondary_key
  sensitive   = true
}

output "cosmosdb_account_primary_readonly_key" {
  description = "The primary readonly key for the CosmosDB account."
  value       = azurerm_cosmosdb_account.main.primary_readonly_key
  sensitive   = true
}

output "cosmosdb_account_secondary_readonly_key" {
  description = "The secondary readonly key for the CosmosDB account."
  value       = azurerm_cosmosdb_account.main.secondary_readonly_key
  sensitive   = true
}

output "cosmosdb_account_connection_strings" {
  description = "All MongoDB connection strings for this CosmosDB account."
  value = {
    primary            = azurerm_cosmosdb_account.main.primary_mongodb_connection_string
    secondary          = azurerm_cosmosdb_account.main.secondary_mongodb_connection_string
    primary_readonly   = azurerm_cosmosdb_account.main.primary_readonly_mongodb_connection_string
    secondary_readonly = azurerm_cosmosdb_account.main.secondary_readonly_mongodb_connection_string
  }
  sensitive = true
}

output "cosmosdb_account_mongo_connection_string" {
  description = "The primary MongoDB connection string for the CosmosDB account."
  value       = azurerm_cosmosdb_account.main.primary_mongodb_connection_string
  sensitive   = true
}

output "cosmosdb_account_secondary_mongo_connection_string" {
  description = "The secondary MongoDB connection string for the CosmosDB account."
  value       = azurerm_cosmosdb_account.main.secondary_mongodb_connection_string
  sensitive   = true
}

output "cosmosdb_account_primary_readonly_mongo_connection_string" {
  description = "The primary readonly MongoDB connection string for the CosmosDB account."
  value       = azurerm_cosmosdb_account.main.primary_readonly_mongodb_connection_string
  sensitive   = true
}

output "cosmosdb_account_secondary_readonly_mongo_connection_string" {
  description = "The secondary readonly MongoDB connection string for the CosmosDB account."
  value       = azurerm_cosmosdb_account.main.secondary_readonly_mongodb_connection_string
  sensitive   = true
}

output "cosmosdb_account_identity" {
  description = "The managed identity of the CosmosDB account."
  value = {
    principal_id = azurerm_cosmosdb_account.main.identity[0].principal_id
    tenant_id    = azurerm_cosmosdb_account.main.identity[0].tenant_id
    type         = azurerm_cosmosdb_account.main.identity[0].type
  }
}

output "cosmosdb_databases" {
  description = "A map of the created MongoDB databases with their IDs."
  value = {
    for db_name, db in azurerm_cosmosdb_mongo_database.databases : db_name => {
      id   = db.id
      name = db.name
    }
  }
}

output "cosmosdb_collections" {
  description = "A map of the created MongoDB collections with their details."
  value = {
    for collection_key, collection in azurerm_cosmosdb_mongo_collection.collections : collection_key => {
      id            = collection.id
      name          = collection.name
      database_name = collection.database_name
      shard_key     = collection.shard_key
    }
  }
}