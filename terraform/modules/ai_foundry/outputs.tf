output "ai_foundry_id" {
  description = "The ID of the AI Foundry resource."
  value       = azapi_resource.ai_foundry.id
}

output "ai_foundry_name" {
  description = "The name of the AI Foundry resource."
  value       = azapi_resource.ai_foundry.name
}

output "ai_foundry_project_id" {
  description = "The ID of the AI Foundry project."
  value       = azapi_resource.ai_foundry_project.id
}

output "ai_foundry_project_name" {
  description = "The name of the AI Foundry project."
  value       = azapi_resource.ai_foundry_project.name
}

output "gpt_deployment_id" {
  description = "The ID of the GPT deployment."
  value       = azurerm_cognitive_deployment.aifoundry_deployment_gpt_4o.id
}

output "gpt_deployment_name" {
  description = "The name of the GPT deployment."
  value       = azurerm_cognitive_deployment.aifoundry_deployment_gpt_4o.name
}
