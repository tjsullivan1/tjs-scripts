# Data Sources
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_service_plan" "main" {
  name                = "asp-${var.web_app_name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Windows"
  sku_name            = "P2v3"
}

# Web Apps
resource "azurerm_windows_web_app" "main" {
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
      current_stack  = var.dotnet_version != "" ? "dotnet" : (var.node_version != "" ? "node" : "dotnet")
      dotnet_version = var.dotnet_version != "" ? var.dotnet_version : "v6.0"
      node_version   = var.node_version != "" ? var.node_version : null
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
resource "azurerm_windows_web_app_slot" "staging" {
  count = var.create_staging_slot ? var.web_app_count : 0

  name           = "staging"
  app_service_id = azurerm_windows_web_app.main[count.index].id

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
    "SLOT_NAME"                = "staging"
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
      current_stack  = var.dotnet_version != "" ? "dotnet" : (var.node_version != "" ? "node" : "dotnet")
      dotnet_version = var.dotnet_version != "" ? var.dotnet_version : "v6.0"
      node_version   = var.node_version != "" ? var.node_version : null
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

# Canary Deployment Slots
resource "azurerm_windows_web_app_slot" "canary" {
  count = var.create_canary_slot ? var.web_app_count : 0

  name           = "canary"
  app_service_id = azurerm_windows_web_app.main[count.index].id

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
    "SLOT_NAME"                = "canary"
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
      current_stack  = var.dotnet_version != "" ? "dotnet" : (var.node_version != "" ? "node" : "dotnet")
      dotnet_version = var.dotnet_version != "" ? var.dotnet_version : "v6.0"
      node_version   = var.node_version != "" ? var.node_version : null
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

# QA Deployment Slots
resource "azurerm_windows_web_app_slot" "qa" {
  count = var.create_qa_slot ? var.web_app_count : 0

  name           = "qa"
  app_service_id = azurerm_windows_web_app.main[count.index].id

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
    "SLOT_NAME"                = "qa"
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
      current_stack  = var.dotnet_version != "" ? "dotnet" : (var.node_version != "" ? "node" : "dotnet")
      dotnet_version = var.dotnet_version != "" ? var.dotnet_version : "v6.0"
      node_version   = var.node_version != "" ? var.node_version : null
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
