# Resource Group outputs
output "resource_group_id" {
  description = "The ID of the created resource group."
  value       = azurerm_resource_group.main.id
}

output "resource_group_name" {
  description = "The name of the created resource group."
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "The location of the created resource group."
  value       = azurerm_resource_group.main.location
}

# AI Foundry outputs
output "ai_foundry_id" {
  description = "The ID of the AI Foundry resource."
  value       = module.ai_foundry.ai_foundry_id
}

output "ai_foundry_name" {
  description = "The name of the AI Foundry resource."
  value       = module.ai_foundry.ai_foundry_name
}

output "ai_foundry_project_id" {
  description = "The ID of the AI Foundry project."
  value       = module.ai_foundry.ai_foundry_project_id
}

output "ai_foundry_project_name" {
  description = "The name of the AI Foundry project."
  value       = module.ai_foundry.ai_foundry_project_name
}

output "gpt_deployment_id" {
  description = "The ID of the GPT deployment."
  value       = module.ai_foundry.gpt_deployment_id
}

output "gpt_deployment_name" {
  description = "The name of the GPT deployment."
  value       = module.ai_foundry.gpt_deployment_name
}

# CosmosDB outputs
output "cosmosdb_account_id" {
  description = "The ID of the CosmosDB account."
  value       = module.cosmosdb.cosmosdb_account_id
}

output "cosmosdb_account_name" {
  description = "The name of the CosmosDB account."
  value       = module.cosmosdb.cosmosdb_account_name
}

output "cosmosdb_account_endpoint" {
  description = "The endpoint used to connect to the CosmosDB account."
  value       = module.cosmosdb.cosmosdb_account_endpoint
}

output "cosmosdb_account_primary_key" {
  description = "The primary key for the CosmosDB account."
  value       = module.cosmosdb.cosmosdb_account_primary_key
  sensitive   = true
}

output "cosmosdb_account_connection_strings" {
  description = "A list of connection strings available for this CosmosDB account."
  value       = module.cosmosdb.cosmosdb_account_connection_strings
  sensitive   = true
}

output "cosmosdb_databases" {
  description = "A map of the created databases with their IDs."
  value       = module.cosmosdb.cosmosdb_databases
}

output "cosmosdb_containers" {
  description = "A map of the created containers with their details."
  value       = module.cosmosdb.cosmosdb_containers
}