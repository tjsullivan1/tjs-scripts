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

# Networking outputs
output "virtual_network_id" {
  description = "The ID of the virtual network (existing network when use_existing_network is true)."
  value       = var.use_existing_network ? data.azurerm_virtual_network.existing[0].id : null
}

output "virtual_network_name" {
  description = "The name of the virtual network (existing network when use_existing_network is true)."
  value       = var.use_existing_network ? data.azurerm_virtual_network.existing[0].name : null
}

output "virtual_network_address_space" {
  description = "The address space of the virtual network (existing network when use_existing_network is true)."
  value       = var.use_existing_network ? data.azurerm_virtual_network.existing[0].address_space : null
}

output "subnet_id" {
  description = "The ID of the subnet (existing subnet when use_existing_network is true)."
  value       = var.use_existing_network ? data.azurerm_subnet.pe[0].id : null
}

output "subnet_name" {
  description = "The name of the subnet (existing subnet when use_existing_network is true)."
  value       = var.use_existing_network ? data.azurerm_subnet.pe[0].name : null
}

output "subnet_address_prefixes" {
  description = "The address prefixes of the subnet (existing subnet when use_existing_network is true)."
  value       = var.use_existing_network ? data.azurerm_subnet.pe[0].address_prefixes : null
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

# MongoDB outputs
output "cosmosdb_mongo_account_id" {
  description = "The ID of the CosmosDB MongoDB account."
  value       = var.enable_mongodb ? module.cosmosdb_mongo[0].cosmosdb_account_id : null
}

output "cosmosdb_mongo_account_name" {
  description = "The name of the CosmosDB MongoDB account."
  value       = var.enable_mongodb ? module.cosmosdb_mongo[0].cosmosdb_account_name : null
}

output "cosmosdb_mongo_account_endpoint" {
  description = "The endpoint used to connect to the CosmosDB MongoDB account."
  value       = var.enable_mongodb ? module.cosmosdb_mongo[0].cosmosdb_account_endpoint : null
}

output "cosmosdb_mongo_connection_string" {
  description = "The primary MongoDB connection string for the CosmosDB account."
  value       = var.enable_mongodb ? module.cosmosdb_mongo[0].cosmosdb_account_mongo_connection_string : null
  sensitive   = true
}

output "cosmosdb_mongo_readonly_connection_string" {
  description = "The primary readonly MongoDB connection string for the CosmosDB account."
  value       = var.enable_mongodb ? module.cosmosdb_mongo[0].cosmosdb_account_primary_readonly_mongo_connection_string : null
  sensitive   = true
}

output "cosmosdb_mongo_connection_strings" {
  description = "All MongoDB connection strings for the CosmosDB account."
  value       = var.enable_mongodb ? module.cosmosdb_mongo[0].cosmosdb_account_connection_strings : null
  sensitive   = true
}

output "cosmosdb_mongo_databases" {
  description = "A map of the created MongoDB databases with their IDs."
  value       = var.enable_mongodb ? module.cosmosdb_mongo[0].cosmosdb_databases : null
}

output "cosmosdb_mongo_collections" {
  description = "A map of the created MongoDB collections with their details."
  value       = var.enable_mongodb ? module.cosmosdb_mongo[0].cosmosdb_collections : null
}

# Private Endpoint outputs
output "private_endpoint_cosmosdb_sql_id" {
  description = "The ID of the CosmosDB SQL private endpoint."
  value       = var.enable_private_endpoints ? azurerm_private_endpoint.cosmosdb_sql[0].id : null
}

output "private_endpoint_cosmosdb_sql_ip" {
  description = "The private IP address of the CosmosDB SQL private endpoint."
  value       = var.enable_private_endpoints ? azurerm_private_endpoint.cosmosdb_sql[0].private_service_connection[0].private_ip_address : null
}

output "private_endpoint_cosmosdb_mongo_id" {
  description = "The ID of the CosmosDB MongoDB private endpoint."
  value       = var.enable_private_endpoints && var.enable_mongodb ? azurerm_private_endpoint.cosmosdb_mongo[0].id : null
}

output "private_endpoint_cosmosdb_mongo_ip" {
  description = "The private IP address of the CosmosDB MongoDB private endpoint."
  value       = var.enable_private_endpoints && var.enable_mongodb ? azurerm_private_endpoint.cosmosdb_mongo[0].private_service_connection[0].private_ip_address : null
}

output "private_endpoint_ai_foundry_id" {
  description = "The ID of the AI Foundry private endpoint."
  value       = var.enable_private_endpoints ? azurerm_private_endpoint.ai_foundry[0].id : null
}

output "private_endpoint_ai_foundry_ip" {
  description = "The private IP address of the AI Foundry private endpoint."
  value       = var.enable_private_endpoints ? azurerm_private_endpoint.ai_foundry[0].private_service_connection[0].private_ip_address : null
}

output "private_dns_zone_ids" {
  description = "The IDs of the private DNS zones."
  value = var.enable_private_endpoints ? {
    cosmos_sql         = var.create_private_dns_zones && var.private_dns_zone_ids.cosmos_sql == null ? azurerm_private_dns_zone.cosmos_sql[0].id : var.private_dns_zone_ids.cosmos_sql
    cosmos_mongo       = var.enable_mongodb && var.create_private_dns_zones && var.private_dns_zone_ids.cosmos_mongo == null ? azurerm_private_dns_zone.cosmos_mongo[0].id : var.private_dns_zone_ids.cosmos_mongo
    cognitive_services = var.create_private_dns_zones && var.private_dns_zone_ids.cognitive_services == null ? azurerm_private_dns_zone.cognitive_services[0].id : var.private_dns_zone_ids.cognitive_services
  } : null
}