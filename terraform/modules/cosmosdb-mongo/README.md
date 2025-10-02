# CosmosDB MongoDB API Terraform Module

This Terraform module creates an Azure Cosmos DB account configured for the MongoDB API, along with databases and collections. It provides a comprehensive solution for deploying MongoDB-compatible databases in Azure with all the benefits of Cosmos DB's global distribution, automatic scaling, and enterprise-grade security.

## Features

- **MongoDB API Support**: Full compatibility with MongoDB drivers and tools
- **Global Distribution**: Support for multi-region deployments with automatic failover
- **Flexible Scaling**: Both manual and autoscale throughput options
- **Enterprise Security**: Managed identity, network isolation, and encryption
- **Backup & Recovery**: Configurable backup policies with point-in-time restore
- **Index Management**: Support for custom indexes on collections
- **Sharding**: Support for sharded collections with custom shard keys

## Usage

### Basic Example

```hcl
module "cosmosdb_mongo" {
  source = "./modules/cosmosdb-mongo"

  name                = "myapp-cosmosdb-mongo"
  location            = "East US"
  resource_group_name = "myapp-rg"

  databases = [
    {
      name       = "myapp"
      throughput = 400
      collections = [
        {
          name      = "users"
          shard_key = "user_id"
          indexes = [
            {
              keys   = ["email"]
              unique = true
            }
          ]
        }
      ]
    }
  ]

  tags = {
    Environment = "production"
    Project     = "myapp"
  }
}
```

### Advanced Example with Multiple Regions

```hcl
module "cosmosdb_mongo" {
  source = "./modules/cosmosdb-mongo"

  name                = "myapp-cosmosdb-mongo-global"
  location            = "East US"
  resource_group_name = "myapp-rg"

  # Enable multi-region writes
  enable_multiple_write_locations = true
  enable_automatic_failover       = true

  # Additional geo locations
  geo_locations = [
    {
      location          = "West US"
      failover_priority = 1
      zone_redundant    = true
    },
    {
      location          = "West Europe"
      failover_priority = 2
      zone_redundant    = false
    }
  ]

  # MongoDB-specific capabilities
  capabilities = [
    "EnableMongo",
    "MongoDBv4.0",
    "mongoEnableDocLevelTTL",
    "EnableMongo16MBDocumentSupport"
  ]

  # Network security
  public_network_access_enabled = false
  virtual_network_rules = [
    {
      id = "/subscriptions/{subscription-id}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{vnet}/subnets/{subnet}"
    }
  ]

  # Databases with autoscaling
  databases = [
    {
      name = "ecommerce"
      autoscale_settings = {
        max_throughput = 4000
      }
      collections = [
        {
          name      = "products"
          shard_key = "category"
          autoscale_settings = {
            max_throughput = 4000
          }
          default_ttl_seconds = 2592000  # 30 days
          indexes = [
            {
              keys   = ["name"]
              unique = false
            },
            {
              keys   = ["sku"]
              unique = true
            },
            {
              keys   = ["category", "price"]
              unique = false
            }
          ]
        }
      ]
    }
  ]
}
```

## MongoDB Capabilities

The module supports various MongoDB-specific capabilities:

- `EnableMongo`: Basic MongoDB API support (enabled by default)
- `MongoDBv3.4`: MongoDB version 3.4 compatibility
- `MongoDBv4.0`: MongoDB version 4.0 compatibility  
- `mongoEnableDocLevelTTL`: Document-level TTL support
- `EnableMongo16MBDocumentSupport`: Support for 16MB documents
- `EnableUniqueCompoundNestedDocs`: Unique compound nested documents
- `EnablePartialUniqueIndex`: Partial unique index support
- `DisableRateLimitingResponses`: Disable rate limiting responses

## Index Management

MongoDB collections automatically include the required `_id` index. The module automatically adds this index to all collections, so you only need to specify additional indexes in your configuration:

```hcl
collections = [
  {
    name = "products"
    indexes = [
      {
        keys   = ["name"]        # Additional index on name field
        unique = false
      },
      {
        keys   = ["sku"]         # Unique index on SKU field
        unique = true
      }
    ]
  }
]
```

**Note**: The `_id` index is automatically created and doesn't need to be specified in your configuration.

### Sharding Constraints

When using sharded collections (collections with a `shard_key`), unique indexes must include the shard key field. This is a MongoDB requirement to ensure uniqueness across shards.

**Correct sharded collection configuration:**
```hcl
collections = [
  {
    name      = "user-sessions"
    shard_key = "user_id"
    indexes = [
      {
        keys   = ["user_id", "session_id"]  # Includes shard key
        unique = true
      },
      {
        keys   = ["created_at"]             # Non-unique index (no restriction)
        unique = false
      }
    ]
  }
]
```

**Incorrect configuration (will fail):**
```hcl
collections = [
  {
    name      = "user-sessions"
    shard_key = "user_id"
    indexes = [
      {
        keys   = ["session_id"]  # Missing shard key - will fail!
        unique = true
      }
    ]
  }
]
```

The module includes validation to catch these configuration errors early during planning.

## Backup Strategies

### Periodic Backup (Default)
```hcl
backup = {
  type                = "Periodic"
  interval_in_minutes = 240  # 4 hours
  retention_in_hours  = 8
  storage_redundancy  = "Geo"
}
```

### Continuous Backup
```hcl
backup = {
  type = "Continuous"
  # interval_in_minutes and retention_in_hours not applicable for continuous
}
```

## Network Security

### Public Access with IP Filtering
```hcl
public_network_access_enabled = true
ip_range_filter = [
  "203.0.113.0/24",
  "198.51.100.0/24"
]
```

### Virtual Network Integration
```hcl
public_network_access_enabled    = false
is_virtual_network_filter_enabled = true
virtual_network_rules = [
  {
    id = "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{vnet}/subnets/{subnet}"
    ignore_missing_vnet_service_endpoint = false
  }
]
```

## Connection Strings

The module outputs various connection strings for different access patterns:

- **Primary MongoDB Connection**: For read/write operations
- **Secondary MongoDB Connection**: For failover scenarios
- **Primary Readonly MongoDB Connection**: For read-only operations
- **Secondary Readonly MongoDB Connection**: For read-only failover

Access these via outputs:
```hcl
# Primary connection string
connection_string = module.cosmosdb_mongo.cosmosdb_account_mongo_connection_string

# Readonly connection string
readonly_connection = module.cosmosdb_mongo.cosmosdb_account_primary_readonly_mongo_connection_string
```

## Cost Optimization

### Using Free Tier
```hcl
enable_free_tier = true  # First 1000 RU/s and 25 GB storage free
```

### Autoscaling
```hcl
databases = [
  {
    name = "mydb"
    autoscale_settings = {
      max_throughput = 4000  # Scales from 400 to 4000 RU/s
    }
  }
]
```

### Serverless (when available)
```hcl
capabilities = ["EnableServerless"]
# Note: Serverless accounts don't use throughput settings
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | >= 4.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >= 4.0 |

## Resources

| Name | Type |
|------|------|
| azurerm_cosmosdb_account.main | resource |
| azurerm_cosmosdb_mongo_database.databases | resource |
| azurerm_cosmosdb_mongo_collection.collections | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | The name of the CosmosDB account. Must be globally unique. | `string` | n/a | yes |
| location | The Azure region where the CosmosDB account will be deployed. | `string` | n/a | yes |
| resource_group_name | The name of the resource group where the CosmosDB account will be created. | `string` | n/a | yes |
| offer_type | The offer type for the CosmosDB account. | `string` | `"Standard"` | no |
| consistency_policy | The consistency policy for the CosmosDB account. | `object({...})` | `{consistency_level = "BoundedStaleness", max_interval_in_seconds = 300, max_staleness_prefix = 100000}` | no |
| geo_locations | List of geo locations for the CosmosDB account. | `list(object({...}))` | `[]` | no |
| enable_free_tier | Whether to enable the free tier for the CosmosDB account. | `bool` | `false` | no |
| enable_automatic_failover | Whether to enable automatic failover for the CosmosDB account. | `bool` | `true` | no |
| enable_multiple_write_locations | Whether to enable multiple write locations for the CosmosDB account. | `bool` | `false` | no |
| public_network_access_enabled | Whether to enable public network access for the CosmosDB account. | `bool` | `true` | no |
| ip_range_filter | IP range filter for the CosmosDB account. | `list(string)` | `[]` | no |
| is_virtual_network_filter_enabled | Whether to enable virtual network filter for the CosmosDB account. | `bool` | `false` | no |
| virtual_network_rules | List of virtual network rules for the CosmosDB account. | `list(object({...}))` | `[]` | no |
| capabilities | List of MongoDB-specific capabilities to enable for the CosmosDB account. | `list(string)` | `["EnableMongo"]` | no |
| backup | Backup configuration for the CosmosDB account. | `object({...})` | `{type = "Periodic", interval_in_minutes = 240, retention_in_hours = 8, storage_redundancy = "Geo"}` | no |
| cors_rules | CORS rules for the CosmosDB account. | `list(object({...}))` | `[]` | no |
| identity | Managed identity configuration for the CosmosDB account. | `object({...})` | `{type = "SystemAssigned"}` | no |
| tags | A mapping of tags to assign to the CosmosDB account. | `map(string)` | `{}` | no |
| databases | List of MongoDB databases to create in the CosmosDB account. | `list(object({...}))` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| cosmosdb_account_id | The ID of the CosmosDB account. |
| cosmosdb_account_name | The name of the CosmosDB account. |
| cosmosdb_account_endpoint | The endpoint used to connect to the CosmosDB account. |
| cosmosdb_account_read_endpoints | A list of read endpoints available for this CosmosDB account. |
| cosmosdb_account_write_endpoints | A list of write endpoints available for this CosmosDB account. |
| cosmosdb_account_primary_key | The primary key for the CosmosDB account. (sensitive) |
| cosmosdb_account_secondary_key | The secondary key for the CosmosDB account. (sensitive) |
| cosmosdb_account_primary_readonly_key | The primary readonly key for the CosmosDB account. (sensitive) |
| cosmosdb_account_secondary_readonly_key | The secondary readonly key for the CosmosDB account. (sensitive) |
| cosmosdb_account_connection_strings | A list of connection strings available for this CosmosDB account. (sensitive) |
| cosmosdb_account_mongo_connection_string | The primary MongoDB connection string for the CosmosDB account. (sensitive) |
| cosmosdb_account_secondary_mongo_connection_string | The secondary MongoDB connection string for the CosmosDB account. (sensitive) |
| cosmosdb_account_primary_readonly_mongo_connection_string | The primary readonly MongoDB connection string for the CosmosDB account. (sensitive) |
| cosmosdb_account_secondary_readonly_mongo_connection_string | The secondary readonly MongoDB connection string for the CosmosDB account. (sensitive) |
| cosmosdb_account_identity | The managed identity of the CosmosDB account. |
| cosmosdb_databases | A map of the created MongoDB databases with their IDs. |
| cosmosdb_collections | A map of the created MongoDB collections with their details. |

## License

This module is released under the MIT License. See LICENSE file for details.

## Contributing

Contributions are welcome! Please read the contributing guidelines and submit pull requests for any improvements.

## Support

For issues related to this module, please create an issue in the repository. For Azure Cosmos DB support, refer to the [official Azure documentation](https://docs.microsoft.com/en-us/azure/cosmos-db/).