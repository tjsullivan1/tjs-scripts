# =============================================================================
# Endpoints
# =============================================================================

output "apim_gateway_url" {
  description = "APIM gateway base URL."
  value       = azurerm_api_management.this.gateway_url
}

output "openai_api_path" {
  description = "Full base URL for the OpenAI Gateway API."
  value       = "${azurerm_api_management.this.gateway_url}/openai"
}

output "foundry_endpoint" {
  description = "AI Foundry endpoint."
  value       = azurerm_cognitive_account.foundry.endpoint
}

# =============================================================================
# APIM Subscription Keys
# =============================================================================

output "subscription_key_alpha_standard" {
  description = "APIM subscription key for Team Alpha (Standard)."
  value       = azurerm_api_management_subscription.alpha_standard.primary_key
  sensitive   = true
}

output "subscription_key_bravo_premium" {
  description = "APIM subscription key for Team Bravo (Premium)."
  value       = azurerm_api_management_subscription.bravo_premium.primary_key
  sensitive   = true
}

output "subscription_key_charlie_standard" {
  description = "APIM subscription key for Team Charlie (Standard)."
  value       = azurerm_api_management_subscription.charlie_standard.primary_key
  sensitive   = true
}

# =============================================================================
# Entra ID — Consumer Credentials
# =============================================================================

output "api_audience" {
  description = "Audience URI for JWT validation."
  value       = one(azuread_application.api.identifier_uris)
}

output "tenant_id" {
  description = "Entra ID tenant ID."
  value       = data.azurerm_client_config.current.tenant_id
}

output "team_alpha_client_id" {
  description = "Team Alpha service principal client ID."
  value       = azuread_application.team_alpha.client_id
}

output "team_alpha_client_secret" {
  description = "Team Alpha service principal client secret."
  value       = azuread_application_password.team_alpha.value
  sensitive   = true
}

output "team_bravo_client_id" {
  description = "Team Bravo service principal client ID."
  value       = azuread_application.team_bravo.client_id
}

output "team_bravo_client_secret" {
  description = "Team Bravo service principal client secret."
  value       = azuread_application_password.team_bravo.value
  sensitive   = true
}

output "team_charlie_client_id" {
  description = "Team Charlie service principal client ID."
  value       = azuread_application.team_charlie.client_id
}

output "team_charlie_client_secret" {
  description = "Team Charlie service principal client secret."
  value       = azuread_application_password.team_charlie.value
  sensitive   = true
}

# =============================================================================
# Monitoring
# =============================================================================

output "application_insights_connection_string" {
  description = "Application Insights connection string for querying metrics."
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for KQL queries."
  value       = azurerm_log_analytics_workspace.this.id
}

output "resource_group_name" {
  description = "Resource group name."
  value       = azurerm_resource_group.this.name
}

# =============================================================================
# Key Vault
# =============================================================================

output "key_vault_name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.this.name
}
