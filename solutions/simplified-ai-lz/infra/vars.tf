variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group to create."
  type        = string
}

variable "ai_foundry_name" {
  description = "The name prefix for the AI Foundry resource."
  type        = string
  default     = "aifoundry"
}

variable "sku_name" {
  description = "The SKU name for the AI Foundry service."
  type        = string
  default     = "S0"
}

variable "disable_local_auth" {
  description = "Whether to disable local authentication (API key). Set to true for Entra ID only."
  type        = bool
  default     = false
}

variable "gpt_deployment_name" {
  description = "The name of the GPT deployment."
  type        = string
  default     = "gpt-4o"
}

variable "gpt_model_name" {
  description = "The name of the GPT model to deploy."
  type        = string
  default     = "gpt-4o"
}

variable "gpt_model_version" {
  description = "The version of the GPT model to deploy."
  type        = string
  default     = "2024-11-20"
}

variable "gpt_sku_name" {
  description = "The SKU name for the GPT deployment."
  type        = string
  default     = "GlobalStandard"
}

variable "gpt_capacity" {
  description = "The capacity for the GPT deployment."
  type        = number
  default     = 1
}

variable "project_name" {
  description = "The name prefix for the AI Foundry project."
  type        = string
  default     = "project"
}

variable "project_display_name" {
  description = "The display name of the AI Foundry project."
  type        = string
  default     = "AI Foundry Project"
}

variable "project_description" {
  description = "The description of the AI Foundry project."
  type        = string
  default     = "AI Foundry project for machine learning workloads"
}

# CosmosDB Variables
variable "cosmosdb_name" {
  description = "The name of the CosmosDB account. Must be globally unique."
  type        = string
  default     = "cosmosdb-ai-lz"
}

variable "cosmosdb_consistency_policy" {
  description = "The consistency policy for the CosmosDB account."
  type = object({
    consistency_level       = string
    max_interval_in_seconds = optional(number, 300)
    max_staleness_prefix    = optional(number, 100000)
  })
  default = {
    consistency_level       = "Session"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }
}

variable "cosmosdb_backup" {
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
}

variable "cosmosdb_capabilities" {
  description = "List of capabilities to enable for the CosmosDB account."
  type        = list(string)
  default     = []
}

variable "cosmosdb_databases" {
  description = "List of databases to create in the CosmosDB account."
  type = list(object({
    name       = string
    throughput = optional(number)
    autoscale_settings = optional(object({
      max_throughput = number
    }))
    containers = optional(list(object({
      name                  = string
      partition_key_path    = string
      partition_key_version = optional(number, 1)
      throughput            = optional(number)
      autoscale_settings = optional(object({
        max_throughput = number
      }))
      default_ttl = optional(number, -1)
      unique_key = optional(list(object({
        paths = list(string)
      })), [])
      included_path = optional(list(object({
        path = string
      })), [])
      excluded_path = optional(list(object({
        path = string
      })), [])
      composite_index = optional(list(object({
        index = list(object({
          path  = string
          order = string
        }))
      })), [])
      spatial_index = optional(list(object({
        path = string
      })), [])
    })), [])
  }))
  default = [
    {
      name       = "ai-data"
      throughput = 400
      containers = [
        {
          name               = "training-data"
          partition_key_path = "/datasetId"
          throughput         = 400
          default_ttl        = -1
        },
        {
          name               = "model-metadata"
          partition_key_path = "/modelId"
          throughput         = 400
          default_ttl        = -1
        },
        {
          name               = "inference-logs"
          partition_key_path = "/sessionId"
          throughput         = 400
          default_ttl        = 2592000 # 30 days
        }
      ]
    }
  ]
}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
  default     = {}
}

# MongoDB Variables
variable "enable_mongodb" {
  description = "Whether to deploy CosmosDB MongoDB API alongside SQL API."
  type        = bool
  default     = false
}

variable "cosmosdb_mongo_name" {
  description = "The name of the CosmosDB MongoDB account. Must be globally unique."
  type        = string
  default     = "cosmosdb-mongo-ai-lz"
}

variable "cosmosdb_mongo_consistency_policy" {
  description = "The consistency policy for the CosmosDB MongoDB account."
  type = object({
    consistency_level       = string
    max_interval_in_seconds = optional(number, 300)
    max_staleness_prefix    = optional(number, 100000)
  })
  default = {
    consistency_level       = "Session"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }
}

variable "cosmosdb_mongo_backup" {
  description = "Backup configuration for the CosmosDB MongoDB account."
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
}

variable "cosmosdb_mongo_capabilities" {
  description = "List of MongoDB-specific capabilities to enable for the CosmosDB account."
  type        = list(string)
  default     = ["EnableMongo", "MongoDBv4.0", "mongoEnableDocLevelTTL"]
}

variable "cosmosdb_mongo_public_access" {
  description = "Whether to enable public network access for the CosmosDB MongoDB account."
  type        = bool
  default     = true
}

variable "cosmosdb_mongo_ip_filter" {
  description = "IP range filter for the CosmosDB MongoDB account. List of IP addresses or CIDR ranges."
  type        = list(string)
  default     = []
}

variable "cosmosdb_mongo_databases" {
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
  default = [
    {
      name       = "ai-mongo-data"
      throughput = 400
      collections = [
        {
          name                = "vector-embeddings"
          shard_key           = "document_id"
          throughput          = 400
          default_ttl_seconds = null
          indexes = [
            {
              keys   = ["embedding_model"]
              unique = false
            },
            {
              keys   = ["document_id"]
              unique = true
            }
          ]
        },
        {
          name                = "chat-sessions"
          shard_key           = "user_id"
          throughput          = 400
          default_ttl_seconds = 2592000 # 30 days
          indexes = [
            {
              keys   = ["user_id", "session_id"]
              unique = true
            },
            {
              keys   = ["user_id", "created_at"]
              unique = false
            }
          ]
        },
        {
          name       = "knowledge-base"
          shard_key  = "category"
          throughput = 400
          indexes = [
            {
              keys   = ["title"]
              unique = false
            },
            {
              keys   = ["category", "created_at"]
              unique = false
            }
          ]
        }
      ]
    }
  ]
}