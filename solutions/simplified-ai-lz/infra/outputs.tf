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