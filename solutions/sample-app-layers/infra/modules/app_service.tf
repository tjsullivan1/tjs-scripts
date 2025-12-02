variable "https_only" {
  description = "Flag to enable HTTPS only"
  type        = bool
  default     = true  
}

variable "ftp_publish_basic_authentication_enabled" {
  description = "Flag to enable FTP publish basic authentication"
  type        = bool
  default     = false
}

variable "webdeploy_publish_basic_authentication_enabled" {
  description = "Flag to enable WebDeploy publish basic authentication"
  type        = bool
  default     = false
  
}

variable "web_app_name" {
  description = "The name of the web app"
  type        = string  
}

variable "user_managed_identity" {
  description = "The user managed identity to use for the app service"
  type        = string
}

variable "outbound_subnet_id" {
  description = "The subnet id to use for the outbound traffic"
  type        = string
}

variable "key_vault_uri" {
  description = "The key vault uri"
  type        = string  
}

variable "app_settings" {
  description = "The app settings to use for the app service"
  type        = map(string)
}

variable "service_plan_id" {
  description = "The service plan id"
  type        = string
}

variable "resource_group_name" {
  description = "The resource group name"
  type        = string
}

variable "location" {
  description = "The location"
  type        = string
}

variable "virtual_applications" {
  description = "The virtual applications"
  type        = list(object({
    virtual_path = string
    physical_path = string
  }))
  
}

resource "azurerm_windows_web_app" "app01" {
  name                = var.web_app_name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = var.service_plan_id

  https_only = var.https_only

  ftp_publish_basic_authentication_enabled       = var.ftp_publish_basic_authentication_enabled
  webdeploy_publish_basic_authentication_enabled = var.webdeploy_publish_basic_authentication_enabled

  // This is the wire-up to the outbound/egress subnet
  virtual_network_subnet_id = var.outbound_subnet_id

  // This is the user that will be use to access the key vault secrets
  key_vault_reference_identity_id = var.user_managed_identity

  // Setup the app service with a user assigned identity
  identity {
    type = "UserAssigned"
    identity_ids = [var.user_managed_identity]
  }

  site_config {
    vnet_route_all_enabled = true
    use_32_bit_worker      = false
    http2_enabled          = true
    always_on              = true
    ftps_state             = "Disabled"

    application_stack {
      current_stack = "dotnet"
      dotnet_version = "v8.0"
    }
  }

  app_settings = var.app_settings
}

output "default_hostname" {
  value = azurerm_windows_web_app.app01.default_hostname  
}