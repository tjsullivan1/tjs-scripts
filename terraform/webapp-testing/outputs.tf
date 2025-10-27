output "web_app_names" {
  description = "Names of the created web apps"
  value       = azurerm_linux_web_app.main[*].name
}

output "web_app_urls" {
  description = "Default URLs of the web apps"
  value       = azurerm_linux_web_app.main[*].default_hostname
}

output "web_app_ids" {
  description = "Resource IDs of the web apps"
  value       = azurerm_linux_web_app.main[*].id
}

output "web_app_outbound_ip_addresses" {
  description = "Outbound IP addresses for the web apps"
  value       = azurerm_linux_web_app.main[*].outbound_ip_addresses
}

output "web_app_possible_outbound_ip_addresses" {
  description = "Possible outbound IP addresses for the web apps"
  value       = azurerm_linux_web_app.main[*].possible_outbound_ip_addresses
}

output "web_app_staging_slot_names" {
  description = "Names of the staging deployment slots (if created)"
  value       = var.create_staging_slot ? azurerm_linux_web_app_slot.staging[*].name : []
}

output "web_app_staging_slot_urls" {
  description = "URLs of the staging deployment slots (if created)"
  value       = var.create_staging_slot ? azurerm_linux_web_app_slot.staging[*].default_hostname : []
}

output "web_app_staging_slot_ids" {
  description = "Resource IDs of the staging deployment slots (if created)"
  value       = var.create_staging_slot ? azurerm_linux_web_app_slot.staging[*].id : []
}

output "service_plan_id" {
  description = "ID of the App Service Plan"
  value       = azurerm_service_plan.main.id
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = data.azurerm_resource_group.main.name
}
