# CosmosDB Account with MongoDB API
resource "azurerm_cosmosdb_account" "main" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = var.offer_type
  kind                = "MongoDB"

  free_tier_enabled                 = var.enable_free_tier
  automatic_failover_enabled        = var.enable_automatic_failover
  multiple_write_locations_enabled  = var.enable_multiple_write_locations
  public_network_access_enabled     = var.public_network_access_enabled
  ip_range_filter                   = var.ip_range_filter
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

  # MongoDB capabilities
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

# MongoDB Databases
resource "azurerm_cosmosdb_mongo_database" "databases" {
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

# MongoDB Collections
resource "azurerm_cosmosdb_mongo_collection" "collections" {
  for_each = {
    for collection in flatten([
      for db in var.databases : [
        for coll in db.collections : {
          key                 = "${db.name}-${coll.name}"
          database_name       = db.name
          name                = coll.name
          shard_key           = coll.shard_key
          throughput          = coll.throughput
          autoscale_settings  = coll.autoscale_settings
          default_ttl_seconds = coll.default_ttl_seconds
          indexes             = coll.indexes
        }
      ]
    ]) : collection.key => collection
  }

  name                = each.value.name
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = each.value.database_name
  shard_key           = each.value.shard_key
  throughput          = each.value.throughput
  default_ttl_seconds = each.value.default_ttl_seconds

  dynamic "autoscale_settings" {
    for_each = each.value.autoscale_settings != null ? [each.value.autoscale_settings] : []
    content {
      max_throughput = autoscale_settings.value.max_throughput
    }
  }

  dynamic "index" {
    for_each = each.value.indexes
    content {
      keys   = index.value.keys
      unique = index.value.unique
    }
  }

  depends_on = [azurerm_cosmosdb_mongo_database.databases]
}