resource "azurerm_windows_web_app" "frontend" {
  name                = local.web_app_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  https_only = true

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  // This is the wire-up to the outbound/egress subnet
  virtual_network_subnet_id = azurerm_subnet.appOutbound.id

  // This is the user that will be use to access the key vault secrets
 #  key_vault_reference_identity_id = var.user_managed_identity

  // Setup the app service with a user assigned identity
  identity {
    type = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.user_identity.id ]
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

  app_settings = {
    "MY_SETTING" = "Something Special!"
    # "MY_SECRET"  = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/TestSecret)"
  }
}

resource "azurerm_windows_web_app" "api" {
  name                = local.api_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id

  https_only = true

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  // This is the wire-up to the outbound/egress subnet
  virtual_network_subnet_id = azurerm_subnet.appOutbound.id

  // This is the user that will be use to access the key vault secrets
 #  key_vault_reference_identity_id = var.user_managed_identity

  // Setup the app service with a user assigned identity
  identity {
    type = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.user_identity.id ]
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

  app_settings = {
    "MY_SETTING" = "Something Special!"
    # "MY_SECRET"  = "@Microsoft.KeyVault(SecretUri=${var.key_vault_uri}secrets/TestSecret)"
  }
}