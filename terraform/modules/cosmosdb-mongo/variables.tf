variable "name" {
  description = "The name of the CosmosDB account. Must be globally unique."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]{3,44}$", var.name))
    error_message = "CosmosDB account name must be 3-44 characters long and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "location" {
  description = "The Azure region where the CosmosDB account will be deployed."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group where the CosmosDB account will be created."
  type        = string
}

variable "offer_type" {
  description = "The offer type for the CosmosDB account."
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard"], var.offer_type)
    error_message = "Offer type must be 'Standard'."
  }
}

variable "consistency_policy" {
  description = "The consistency policy for the CosmosDB account."
  type = object({
    consistency_level       = string
    max_interval_in_seconds = optional(number, 300)
    max_staleness_prefix    = optional(number, 100000)
  })
  default = {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }
  validation {
    condition = contains([
      "BoundedStaleness",
      "Eventual",
      "Session",
      "Strong",
      "ConsistentPrefix"
    ], var.consistency_policy.consistency_level)
    error_message = "Consistency level must be one of: BoundedStaleness, Eventual, Session, Strong, ConsistentPrefix."
  }
}

variable "geo_locations" {
  description = "List of geo locations for the CosmosDB account."
  type = list(object({
    location          = string
    failover_priority = number
    zone_redundant    = optional(bool, false)
  }))
  default = []
}

variable "enable_free_tier" {
  description = "Whether to enable the free tier for the CosmosDB account."
  type        = bool
  default     = false
}

variable "enable_automatic_failover" {
  description = "Whether to enable automatic failover for the CosmosDB account."
  type        = bool
  default     = true
}

variable "enable_multiple_write_locations" {
  description = "Whether to enable multiple write locations for the CosmosDB account."
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Whether to enable public network access for the CosmosDB account."
  type        = bool
  default     = true
}

variable "ip_range_filter" {
  description = "IP range filter for the CosmosDB account. Comma-separated list of IP addresses or CIDR ranges."
  type        = list(string)
  default     = []
}

variable "is_virtual_network_filter_enabled" {
  description = "Whether to enable virtual network filter for the CosmosDB account."
  type        = bool
  default     = false
}

variable "virtual_network_rules" {
  description = "List of virtual network rules for the CosmosDB account."
  type = list(object({
    id                                   = string
    ignore_missing_vnet_service_endpoint = optional(bool, false)
  }))
  default = []
}

variable "capabilities" {
  description = "List of MongoDB-specific capabilities to enable for the CosmosDB account."
  type        = list(string)
  default     = ["EnableMongo"]
  validation {
    condition = alltrue([
      for capability in var.capabilities : contains([
        "EnableMongo",
        "MongoDBv3.4",
        "mongoEnableDocLevelTTL",
        "MongoDBv4.0",
        "EnableMongo16MBDocumentSupport",
        "EnableUniqueCompoundNestedDocs",
        "EnablePartialUniqueIndex",
        "DisableRateLimitingResponses"
      ], capability)
    ])
    error_message = "Invalid capability specified. Valid MongoDB capabilities are: EnableMongo, MongoDBv3.4, mongoEnableDocLevelTTL, MongoDBv4.0, EnableMongo16MBDocumentSupport, EnableUniqueCompoundNestedDocs, EnablePartialUniqueIndex, DisableRateLimitingResponses."
  }
}

variable "backup" {
  description = "Backup configuration for the CosmosDB account."
  type = object({
    type                = string
    interval_in_minutes = optional(number, 240)
    retention_in_hours  = optional(number, 8)
    storage_redundancy  = optional(string, "Geo")
  })
  default = {
    type                = "Periodic"
    interval_in_minutes = 240
    retention_in_hours  = 8
    storage_redundancy  = "Geo"
  }
  validation {
    condition     = contains(["Periodic", "Continuous"], var.backup.type)
    error_message = "Backup type must be either 'Periodic' or 'Continuous'."
  }
}

variable "cors_rules" {
  description = "CORS rules for the CosmosDB account."
  type = list(object({
    allowed_headers    = list(string)
    allowed_methods    = list(string)
    allowed_origins    = list(string)
    exposed_headers    = list(string)
    max_age_in_seconds = number
  }))
  default = []
}

variable "identity" {
  description = "Managed identity configuration for the CosmosDB account."
  type = object({
    type         = string
    identity_ids = optional(list(string), [])
  })
  default = {
    type = "SystemAssigned"
  }
  validation {
    condition     = contains(["SystemAssigned", "UserAssigned", "SystemAssigned,UserAssigned"], var.identity.type)
    error_message = "Identity type must be one of: SystemAssigned, UserAssigned, SystemAssigned,UserAssigned."
  }
}

variable "tags" {
  description = "A mapping of tags to assign to the CosmosDB account."
  type        = map(string)
  default     = {}
}

variable "databases" {
  description = "List of MongoDB databases to create in the CosmosDB account."
  type = list(object({
    name       = string
    throughput = optional(number)
    autoscale_settings = optional(object({
      max_throughput = number
    }))
    collections = optional(list(object({
      name       = string
      shard_key  = optional(string)
      throughput = optional(number)
      autoscale_settings = optional(object({
        max_throughput = number
      }))
      default_ttl_seconds = optional(number)
      indexes = optional(list(object({
        keys   = list(string)
        unique = optional(bool, false)
      })), [])
    })), [])
  }))
  default = []
  validation {
    condition = alltrue([
      for db in var.databases : alltrue([
        for collection in db.collections :
        collection.shard_key == null ? true : can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", collection.shard_key))
      ])
    ])
    error_message = "Shard key must be a valid MongoDB field name (alphanumeric and underscores, starting with letter or underscore)."
  }
}