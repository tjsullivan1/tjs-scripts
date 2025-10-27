# Data Sources
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_service_plan" "main" {
  name                = "asp-"${var.web_app_name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "P2v3"
}

# Web Apps
resource "azurerm_linux_web_app" "main" {
  count = var.web_app_count

  name                = "${var.web_app_name_prefix}-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.main.id

  # Security settings
  https_only                                     = var.https_only
  client_affinity_enabled                        = false
  client_certificate_enabled                     = false
  client_certificate_mode                        = "Required"
  public_network_access_enabled                  = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  # App settings - can be customized per app if needed
  app_settings = merge(var.tags, {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
  })

  tags = var.tags

  site_config {
    always_on = var.always_on

    # Security settings
    ftps_state          = "FtpsOnly"
    http2_enabled       = true
    minimum_tls_version = "1.2"

    # Performance settings
    load_balancing_mode = "LeastRequests"
    use_32_bit_worker   = false
    worker_count        = 1

    # Health check
    health_check_eviction_time_in_min = 0

    # Default documents
    default_documents = [
      "Default.htm",
      "Default.html",
      "Default.asp",
      "index.htm",
      "index.html",
      "iisstart.htm",
      "default.aspx",
      "index.php",
      "hostingstart.html"
    ]

    application_stack {
      # Docker configuration (takes precedence if docker_image is specified)
      docker_image_name        = var.docker_image != "" ? var.docker_image : null
      docker_registry_url      = var.docker_registry_url != "" ? var.docker_registry_url : null
      docker_registry_username = var.docker_registry_username != "" ? var.docker_registry_username : null
      docker_registry_password = var.docker_registry_password != "" ? var.docker_registry_password : null

      # Runtime stack configuration (only used if docker_image is empty)
      dotnet_version = var.docker_image == "" && var.dotnet_version != "" ? var.dotnet_version : null
      node_version   = var.docker_image == "" && var.node_version != "" ? var.node_version : null
      python_version = var.docker_image == "" && var.python_version != "" ? var.python_version : null
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to these as they may be modified by deployments
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      zip_deploy_file
    ]
  }
}

# Deployment Slots
resource "azurerm_linux_web_app_slot" "prod" {
  count = var.create_prod_slot ? var.web_app_count : 0

  name           = "prod"
  app_service_id = azurerm_linux_web_app.main[count.index].id

  # Security settings (inherit from main app)
  https_only                                     = var.https_only
  client_affinity_enabled                        = false
  client_certificate_enabled                     = false
  client_certificate_mode                        = "Required"
  public_network_access_enabled                  = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  # App settings (inherit from main app but can be customized)
  app_settings = merge(var.tags, {
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "SLOT_NAME"                = "prod"
  })

  tags = var.tags

  site_config {
    always_on = var.always_on

    # Security settings
    ftps_state          = "FtpsOnly"
    http2_enabled       = true
    minimum_tls_version = "1.2"

    # Performance settings
    load_balancing_mode = "LeastRequests"
    use_32_bit_worker   = false
    worker_count        = 1

    # Health check
    # health_check_eviction_time_in_min = 0

    # Default documents
    default_documents = [
      "Default.htm",
      "Default.html",
      "Default.asp",
      "index.htm",
      "index.html",
      "iisstart.htm",
      "default.aspx",
      "index.php",
      "hostingstart.html"
    ]

    application_stack {
      # Docker configuration (inherit from main app)
      docker_image_name        = var.docker_image != "" ? var.docker_image : null
      docker_registry_url      = var.docker_registry_url != "" ? var.docker_registry_url : null
      docker_registry_username = var.docker_registry_username != "" ? var.docker_registry_username : null
      docker_registry_password = var.docker_registry_password != "" ? var.docker_registry_password : null

      # Runtime stack configuration (inherit from main app)
      dotnet_version = var.docker_image == "" && var.dotnet_version != "" ? var.dotnet_version : null
      node_version   = var.docker_image == "" && var.node_version != "" ? var.node_version : null
      python_version = var.docker_image == "" && var.python_version != "" ? var.python_version : null
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to these as they may be modified by deployments
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
      zip_deploy_file
    ]
  }
}
