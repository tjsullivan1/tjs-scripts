# CosmosDB Account
resource "azurerm_cosmosdb_account" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = var.offer_type
  kind                = var.kind

  free_tier_enabled                = var.enable_free_tier
  automatic_failover_enabled       = var.enable_automatic_failover
  multiple_write_locations_enabled = var.enable_multiple_write_locations
  public_network_access_enabled    = var.public_network_access_enabled
  ip_range_filter                  = var.ip_range_filter
  is_virtual_network_filter_enabled = var.is_virtual_network_filter_enabled

  consistency_policy {
    consistency_level       = var.consistency_policy.consistency_level
    max_interval_in_seconds = var.consistency_policy.max_interval_in_seconds
    max_staleness_prefix    = var.consistency_policy.max_staleness_prefix
  }

  # Primary geo location (required)
  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = length(var.geo_locations) > 0 ? var.geo_locations[0].zone_redundant : false
  }

  # Additional geo locations
  dynamic "geo_location" {
    for_each = var.geo_locations
    content {
      location          = geo_location.value.location
      failover_priority = geo_location.value.failover_priority
      zone_redundant    = geo_location.value.zone_redundant
    }
  }

  dynamic "capabilities" {
    for_each = var.capabilities
    content {
      name = capabilities.value
    }
  }

  backup {
    type                = var.backup.type
    interval_in_minutes = var.backup.interval_in_minutes
    retention_in_hours  = var.backup.retention_in_hours
    storage_redundancy  = var.backup.storage_redundancy
  }

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers    = cors_rule.value.allowed_headers
      allowed_methods    = cors_rule.value.allowed_methods
      allowed_origins    = cors_rule.value.allowed_origins
      exposed_headers    = cors_rule.value.exposed_headers
      max_age_in_seconds = cors_rule.value.max_age_in_seconds
    }
  }

  dynamic "virtual_network_rule" {
    for_each = var.virtual_network_rules
    content {
      id                                   = virtual_network_rule.value.id
      ignore_missing_vnet_service_endpoint = virtual_network_rule.value.ignore_missing_vnet_service_endpoint
    }
  }

  identity {
    type         = var.identity.type
    identity_ids = var.identity.type == "UserAssigned" || var.identity.type == "SystemAssigned,UserAssigned" ? var.identity.identity_ids : null
  }

  tags = var.tags
}

# SQL Databases
resource "azurerm_cosmosdb_sql_database" "databases" {
  for_each = {
    for db in var.databases : db.name => db
  }

  name                = each.value.name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  throughput          = each.value.throughput

  dynamic "autoscale_settings" {
    for_each = each.value.autoscale_settings != null ? [each.value.autoscale_settings] : []
    content {
      max_throughput = autoscale_settings.value.max_throughput
    }
  }
}

# SQL Containers
resource "azurerm_cosmosdb_sql_container" "containers" {
  for_each = {
    for container in flatten([
      for db in var.databases : [
        for cont in db.containers : {
          key                   = "${db.name}-${cont.name}"
          database_name         = db.name
          name                  = cont.name
          partition_key_path    = cont.partition_key_path
          partition_key_version = cont.partition_key_version
          throughput           = cont.throughput
          autoscale_settings   = cont.autoscale_settings
          default_ttl          = cont.default_ttl
          unique_key           = cont.unique_key
          included_path        = cont.included_path
          excluded_path        = cont.excluded_path
          composite_index      = cont.composite_index
          spatial_index        = cont.spatial_index
        }
      ]
    ]) : container.key => container
  }

  name                  = each.value.name
  resource_group_name   = var.resource_group_name
  account_name          = azurerm_cosmosdb_account.main.name
  database_name         = each.value.database_name
  partition_key_paths   = [each.value.partition_key_path]
  partition_key_version = each.value.partition_key_version
  throughput           = each.value.throughput
  default_ttl          = each.value.default_ttl

  dynamic "autoscale_settings" {
    for_each = each.value.autoscale_settings != null ? [each.value.autoscale_settings] : []
    content {
      max_throughput = autoscale_settings.value.max_throughput
    }
  }

  dynamic "unique_key" {
    for_each = each.value.unique_key
    content {
      paths = unique_key.value.paths
    }
  }

  indexing_policy {
    indexing_mode = "consistent"

    dynamic "included_path" {
      for_each = each.value.included_path
      content {
        path = included_path.value.path
      }
    }

    dynamic "excluded_path" {
      for_each = each.value.excluded_path
      content {
        path = excluded_path.value.path
      }
    }

    dynamic "composite_index" {
      for_each = each.value.composite_index
      content {
        dynamic "index" {
          for_each = composite_index.value.index
          content {
            path  = index.value.path
            order = index.value.order
          }
        }
      }
    }

    dynamic "spatial_index" {
      for_each = each.value.spatial_index
      content {
        path = spatial_index.value.path
      }
    }
  }

  depends_on = [azurerm_cosmosdb_sql_database.databases]
}