# outputs.tf
output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "app_direct_url" {
  description = "Direct App Service URL (cookies are first-party here)"
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "staging_direct_url" {
  description = "Direct staging slot URL"
  value       = "https://${azurerm_linux_web_app_slot.staging.default_hostname}"
}

output "frontdoor_url" {
  description = "Front Door URL (cookies become cross-domain — demonstrates the issue)"
  value       = "https://${azurerm_cdn_frontdoor_endpoint.ep.host_name}"
}

output "app_name" {
  description = "Web app name for deployment commands"
  value       = azurerm_linux_web_app.app.name
}

output "storage_account_name" {
  description = "Storage account for Data Protection keys"
  value       = azurerm_storage_account.dp_keys.name
}

output "custom_domain_url" {
  description = "Custom domain URL via Front Door"
  value       = "https://${var.custom_domain_name}"
}
