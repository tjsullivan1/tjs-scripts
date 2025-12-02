variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "East US"
  validation {
    condition = contains([
      "East US", "East US 2", "West US", "West US 2", "West US 3",
      "Central US", "North Central US", "South Central US", "West Central US",
      "Canada Central", "Canada East",
      "North Europe", "West Europe", "UK South", "UK West",
      "France Central", "Germany West Central", "Switzerland North",
      "Southeast Asia", "East Asia", "Australia East", "Australia Southeast",
      "Japan East", "Japan West", "Korea Central", "Korea South",
      "India Central", "India South", "India West"
    ], var.location)
    error_message = "Location must be a valid Azure region."
  }
}

# Project prefix and stage for naming
variable "project_prefix" {
  description = "Prefix for all resource names (e.g. 'openaiworkshop')"
  type        = string
  default     = "sample"
}

variable "project_stage" {
  description = "Deployment stage (e.g. 'dev', 'prod', 'test')"
  type        = string
  default     = "dev"
}


variable "admin_username" {
  type        = string
  description = "The administrator username of the SQL logical server."
  default     = "azureadmin"
}

variable "admin_password" {
  type        = string
  description = "The administrator password of the SQL logical server."
  sensitive   = true
  default     = null
}