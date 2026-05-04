# main.tf

locals {
  specifier = var.project_name
}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.specifier}"
  location = var.location

  lifecycle {
    ignore_changes = [tags]
  }
}

# Storage Account for shared Data Protection keys
resource "azurerm_storage_account" "dp_keys" {
  name                     = "st${local.specifier}dpkeys"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "dp_keys" {
  name                 = "data-protection-keys"
  storage_account_id   = azurerm_storage_account.dp_keys.id
}

# App Service Plan — S1 is minimum SKU that supports deployment slots
resource "azurerm_service_plan" "asp" {
  name                = "asp-${local.specifier}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "S1"
}

# Linux Web App (.NET 8)
resource "azurerm_linux_web_app" "app" {
  name                = "wa-${local.specifier}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.asp.location
  service_plan_id     = azurerm_service_plan.asp.id

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  site_config {
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 5

    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "SLOT_NAME"                             = "production"
    "SLOT_BANNER_COLOR"                     = "#0078d4"
    "DataProtection__BlobUri"               = "${azurerm_storage_account.dp_keys.primary_blob_endpoint}data-protection-keys/keys.xml"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Staging Slot
resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.app.id

  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  site_config {
    health_check_path                 = "/healthz"
    health_check_eviction_time_in_min = 5

    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "SLOT_NAME"                             = "staging"
    "SLOT_BANNER_COLOR"                     = "#e74c3c"
    "DataProtection__BlobUri"               = "${azurerm_storage_account.dp_keys.primary_blob_endpoint}data-protection-keys/keys.xml"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Traffic routing: send configured % to staging
# azurerm does not expose rampUpRules; use azapi to set the experiment
resource "azapi_update_resource" "traffic_routing" {
  type        = "Microsoft.Web/sites/config@2024-04-01"
  resource_id = "${azurerm_linux_web_app.app.id}/config/web"

  body = {
    properties = {
      experiments = {
        rampUpRules = [
          {
            actionHostName = azurerm_linux_web_app_slot.staging.default_hostname
            reroutePercentage = var.staging_traffic_percent
            name              = "staging"
          }
        ]
      }
    }
  }
}

# Grant both slots access to blob storage for Data Protection keys
resource "azurerm_role_assignment" "app_blob" {
  scope                = azurerm_storage_account.dp_keys.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

resource "azurerm_role_assignment" "staging_blob" {
  scope                = azurerm_storage_account.dp_keys.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app_slot.staging.identity[0].principal_id
}

# Azure Front Door
resource "azurerm_cdn_frontdoor_profile" "afd" {
  name                = "afd-${local.specifier}"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "ep" {
  name                     = "ep-${local.specifier}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
}

resource "azurerm_cdn_frontdoor_origin_group" "app" {
  name                     = "app-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id

  load_balancing {}

  health_probe {
    path                = "/healthz"
    protocol            = "Https"
    interval_in_seconds = 30
    request_type        = "GET"
  }
}

resource "azurerm_cdn_frontdoor_origin" "app" {
  name                          = "app-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.app.id

  enabled                        = true
  host_name                      = azurerm_linux_web_app.app.default_hostname
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = azurerm_linux_web_app.app.default_hostname
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "app" {
  name                          = "app-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.ep.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.app.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.app.id]

  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.app.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  link_to_default_domain = true
}

# Custom Domain

data "azurerm_dns_zone" "zone" {
  name                = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group
}

resource "azurerm_cdn_frontdoor_custom_domain" "app" {
  name                     = "custom-domain"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
  dns_zone_id              = data.azurerm_dns_zone.zone.id
  host_name                = var.custom_domain_name

  tls {
    certificate_type = "ManagedCertificate"
  }
}

# DNS validation TXT record (_dnsauth.<subdomain>)
resource "azurerm_dns_txt_record" "validation" {
  name                = join(".", compact(["_dnsauth", trimsuffix(var.custom_domain_name, ".${var.dns_zone_name}")]))
  zone_name           = data.azurerm_dns_zone.zone.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.app.validation_token
  }
}

# CNAME pointing subdomain to Front Door endpoint
resource "azurerm_dns_cname_record" "app" {
  name                = trimsuffix(var.custom_domain_name, ".${var.dns_zone_name}")
  zone_name           = data.azurerm_dns_zone.zone.name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 3600
  record              = azurerm_cdn_frontdoor_endpoint.ep.host_name
}

# Associate custom domain with the route for activation
resource "azurerm_cdn_frontdoor_custom_domain_association" "app" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.app.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.app.id]
}
