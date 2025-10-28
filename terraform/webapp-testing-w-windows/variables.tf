variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "canadacentral"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-harness-webapps"
}

variable "app_service_plan_name" {
  description = "Name of the App Service Plan"
  type        = string
  default     = "asp-harness"
}

variable "app_service_plan_sku" {
  description = "App Service Plan SKU"
  type        = string
  default     = "B1"
  validation {
    condition = contains([
      "F1", "D1", "B1", "B2", "B3", "S1", "S2", "S3",
      "P1", "P2", "P3", "P1v2", "P2v2", "P3v2", "P1v3", "P2v3", "P3v3"
    ], var.app_service_plan_sku)
    error_message = "The SKU must be a valid App Service Plan SKU."
  }
}

variable "web_app_count" {
  description = "Number of web apps to deploy"
  type        = number
  default     = 1
  validation {
    condition     = var.web_app_count > 0 && var.web_app_count <= 20
    error_message = "Web app count must be between 1 and 20."
  }
}

variable "web_app_name_prefix" {
  description = "Prefix for web app names (will be suffixed with count index)"
  type        = string
  default     = "wa-harness"
  validation {
    condition     = can(regex("^[a-z0-9-]{1,40}$", var.web_app_name_prefix))
    error_message = "Web app name prefix must be 1-40 characters, lowercase letters, numbers, and hyphens only."
  }
}

variable "https_only" {
  description = "Should the web app only accept HTTPS requests"
  type        = bool
  default     = true
}

variable "always_on" {
  description = "Should the web app be always on (not applicable for Free tier)"
  type        = bool
  default     = true
}

variable "dotnet_version" {
  description = ".NET version for the web apps (e.g., 'v6.0', 'v7.0', 'v8.0')"
  type        = string
  default     = "v6.0"
}

variable "node_version" {
  description = "Node.js version for the web apps (e.g., '18-lts', '20-lts'). Leave empty to use .NET stack."
  type        = string
  default     = ""
}

variable "create_staging_slot" {
  description = "Whether to create a 'staging' deployment slot for each web app"
  type        = bool
  default     = true
}

variable "create_canary_slot" {
  description = "Whether to create a 'canary' deployment slot for each web app"
  type        = bool
  default     = false
}

variable "create_qa_slot" {
  description = "Whether to create a 'qa' deployment slot for each web app"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "harness"
    ManagedBy   = "terraform"
  }
}
