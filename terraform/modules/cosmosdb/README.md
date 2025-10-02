# Azure CosmosDB Terraform Module

This Terraform module creates and manages an Azure CosmosDB account with databases and containers. It supports various CosmosDB features including geo-replication, backup policies, virtual network integration, and advanced indexing policies.

## Features

- **Multi-region deployment** with automatic failover
- **Flexible consistency policies** (Strong, Bounded Staleness, Session, Eventual, Consistent Prefix)
- **Backup policies** (Periodic and Continuous)
- **Virtual network integration** and IP filtering
- **Managed identity** support (System Assigned, User Assigned)
- **Advanced indexing policies** with composite and spatial indexes
- **Serverless and provisioned throughput** options
- **Database and container creation** with configurable settings
- **CORS rules** for web applications

## Usage

### Basic Example

```hcl
module "cosmosdb" {
  source = "github.com/tjsullivan1/tjs-scripts//terraform/modules/cosmosdb"

  name                = "my-cosmosdb-account"
  location            = "East US 2"
  resource_group_name = "rg-cosmosdb"

  consistency_policy = {
    consistency_level = "Session"
  }

  databases = [
    {
      name       = "myapp"
      throughput = 400
      containers = [
        {
          name               = "users"
          partition_key_path = "/userId"
          throughput        = 400
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

### Advanced Example with Geo-Replication

```hcl
module "cosmosdb" {
  source = "github.com/tjsullivan1/tjs-scripts//terraform/modules/cosmosdb"

  name                = "global-cosmosdb"
  location            = "East US 2"
  resource_group_name = "rg-cosmosdb-global"

  enable_automatic_failover       = true
  enable_multiple_write_locations = true

  consistency_policy = {
    consistency_level       = "BoundedStaleness"
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_locations = [
    {
      location          = "West US 2"
      failover_priority = 1
      zone_redundant    = true
    },
    {
      location          = "East Asia"
      failover_priority = 2
      zone_redundant    = false
    }
  ]

  backup = {
    type                = "Continuous"
    storage_redundancy  = "Geo"
  }

  capabilities = [
    "EnableAggregationPipeline",
    "EnableServerless"
  ]

  databases = [
    {
      name = "production-db"
      containers = [
        {
          name               = "orders"
          partition_key_path = "/customerId"
          autoscale_settings = {
            max_throughput = 4000
          }
          unique_key = [
            {
              paths = ["/orderNumber"]
            }
          ]
          composite_index = [
            {
              index = [
                {
                  path  = "/customerId"
                  order = "ascending"
                },
                {
                  path  = "/orderDate"
                  order = "descending"
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

### Serverless Example

```hcl
module "cosmosdb_serverless" {
  source = "github.com/tjsullivan1/tjs-scripts//terraform/modules/cosmosdb"

  name                = "serverless-cosmosdb"
  location            = "East US 2"
  resource_group_name = "rg-cosmosdb-serverless"

  capabilities = ["EnableServerless"]

  databases = [
    {
      name = "serverless-db"
      containers = [
        {
          name               = "events"
          partition_key_path = "/eventType"
          # No throughput specified for serverless
        }
      ]
    }
  ]
}
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
| azurerm_cosmosdb_account | resource |
| azurerm_cosmosdb_sql_database | resource |
| azurerm_cosmosdb_sql_container | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | The name of the CosmosDB account. Must be globally unique. | `string` | n/a | yes |
| location | The Azure region where the CosmosDB account will be deployed. | `string` | n/a | yes |
| resource_group_name | The name of the resource group where the CosmosDB account will be created. | `string` | n/a | yes |
| offer_type | The offer type for the CosmosDB account. | `string` | `"Standard"` | no |
| kind | The kind of CosmosDB account to create. | `string` | `"GlobalDocumentDB"` | no |
| consistency_policy | The consistency policy for the CosmosDB account. | `object` | `{consistency_level = "BoundedStaleness", max_interval_in_seconds = 300, max_staleness_prefix = 100000}` | no |
| geo_locations | List of geo locations for the CosmosDB account. | `list(object)` | `[]` | no |
| enable_free_tier | Whether to enable the free tier for the CosmosDB account. | `bool` | `false` | no |
| enable_automatic_failover | Whether to enable automatic failover for the CosmosDB account. | `bool` | `true` | no |
| enable_multiple_write_locations | Whether to enable multiple write locations for the CosmosDB account. | `bool` | `false` | no |
| public_network_access_enabled | Whether to enable public network access for the CosmosDB account. | `bool` | `true` | no |
| ip_range_filter | IP range filter for the CosmosDB account. | `string` | `""` | no |
| capabilities | List of capabilities to enable for the CosmosDB account. | `list(string)` | `[]` | no |
| backup | Backup configuration for the CosmosDB account. | `object` | `{type = "Periodic", interval_in_minutes = 240, retention_in_hours = 8, storage_redundancy = "Geo"}` | no |
| identity | Managed identity configuration for the CosmosDB account. | `object` | `{type = "SystemAssigned"}` | no |
| databases | List of databases to create in the CosmosDB account. | `list(object)` | `[]` | no |
| tags | A mapping of tags to assign to the CosmosDB account. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cosmosdb_account_id | The ID of the CosmosDB account |
| cosmosdb_account_name | The name of the CosmosDB account |
| cosmosdb_account_endpoint | The endpoint used to connect to the CosmosDB account |
| cosmosdb_account_read_endpoints | A list of read endpoints available for this CosmosDB account |
| cosmosdb_account_write_endpoints | A list of write endpoints available for this CosmosDB account |
| cosmosdb_account_primary_key | The primary key for the CosmosDB account (sensitive) |
| cosmosdb_account_secondary_key | The secondary key for the CosmosDB account (sensitive) |
| cosmosdb_account_connection_strings | A list of connection strings available for this CosmosDB account (sensitive) |
| cosmosdb_account_identity | The managed identity of the CosmosDB account |
| cosmosdb_databases | A map of the created databases with their IDs |
| cosmosdb_containers | A map of the created containers with their details |

## Database and Container Configuration

### Database Options

- **throughput**: Provisioned throughput (RU/s) for the database
- **autoscale_settings**: Configure autoscale with max_throughput

### Container Options

- **partition_key_path**: The path to the partition key (e.g., "/userId")
- **partition_key_version**: Version of the partition key (1 or 2)
- **throughput**: Provisioned throughput (RU/s) for the container
- **autoscale_settings**: Configure autoscale with max_throughput
- **default_ttl**: Default Time To Live for documents (-1 for no expiration)
- **unique_key**: Unique key constraints
- **indexing policies**: Configure included/excluded paths, composite and spatial indexes

## Security Best Practices

1. **Network Security**:
   - Set `public_network_access_enabled = false` for production
   - Use virtual network rules for private access
   - Configure IP filtering with specific IP ranges

2. **Authentication**:
   - Use managed identity when possible
   - Rotate access keys regularly
   - Use read-only keys for read operations

3. **Backup and Recovery**:
   - Enable continuous backup for production workloads
   - Configure geo-redundant backup storage
   - Test backup restoration procedures

4. **Monitoring**:
   - Enable diagnostic settings
   - Monitor RU consumption and throttling
   - Set up alerts for availability and performance

## Cost Optimization

1. **Throughput Management**:
   - Use autoscale for variable workloads
   - Monitor and adjust provisioned throughput
   - Consider serverless for dev/test environments

2. **Storage Optimization**:
   - Implement appropriate TTL policies
   - Archive old data to cheaper storage
   - Use indexing policies to optimize storage

3. **Multi-region Considerations**:
   - Only add regions that are needed
   - Use single-region write for cost optimization
   - Consider consistency level impact on cost

## Examples

See the `terraform.tfvars.example` file for detailed configuration examples.

## Contributing

This module follows the repository's Terraform coding standards. Please ensure:

- All variables have proper descriptions and validation
- Resources are properly organized and commented
- Outputs provide useful information for consumers
- Examples demonstrate common use cases