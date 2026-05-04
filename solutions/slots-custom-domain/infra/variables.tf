# variables.tf
variable "location" {
  type        = string
  default     = "eastus2"
  description = "Azure region for all resources."
}

variable "project_name" {
  type        = string
  default     = "slotdemo"
  description = "Short name used in resource naming."
}

variable "custom_domain_name" {
  type        = string
  description = "The fully qualified custom domain name to map to Front Door (e.g., app.example.com)."
}

variable "dns_zone_name" {
  type        = string
  description = "Name of the existing Azure DNS Zone (e.g., example.com)."
}

variable "dns_zone_resource_group" {
  type        = string
  description = "Resource group containing the existing Azure DNS Zone."
}

variable "staging_traffic_percent" {
  type        = number
  default     = 50
  description = "Percentage of traffic routed to the staging slot (0-100)."

  validation {
    condition     = var.staging_traffic_percent >= 0 && var.staging_traffic_percent <= 100
    error_message = "Traffic percentage must be between 0 and 100."
  }
}
