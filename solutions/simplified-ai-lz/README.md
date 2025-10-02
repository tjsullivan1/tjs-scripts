# Simplified AI Landing Zone

This solution provides a simplified Azure landing zone specifically designed for AI workloads. It creates the necessary infrastructure to get started with Azure AI Foundry, including AI services, GPT model deployments, and project management capabilities.

## Architecture

The solution deploys the following Azure resources:

- **Resource Group**: Container for all AI-related resources
- **AI Foundry**: Azure Cognitive Services account configured for AI services
- **GPT Deployment**: OpenAI GPT-4o model deployment for AI workloads
- **AI Project**: Project container for organizing AI assets and workflows
- **CosmosDB**: NoSQL database for storing AI training data, model metadata, and inference logs

## Prerequisites

- Azure subscription with appropriate permissions
- Terraform >= 1.0
- Azure CLI installed and authenticated
- AzAPI Terraform provider for advanced Azure resource management

## Required Azure Permissions

The deployment principal needs the following permissions:
- `Contributor` role on the target subscription or resource group
- `Cognitive Services Contributor` role for AI services management

## Deployment

### 1. Clone and Navigate

```bash
git clone https://github.com/tjsullivan1/tjs-scripts.git
cd tjs-scripts/solutions/simplified-ai-lz/infra
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review and Customize Variables

Copy the example variables file and customize as needed:

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your specific values
```

Required variables:
- `location`: Azure region for deployment
- `resource_group_name`: Name for the resource group

### 4. Plan and Apply

```bash
terraform plan
terraform apply
```

## Configuration

### Variables

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `location` | Azure region for deployment | string | - | Yes |
| `resource_group_name` | Name of the resource group | string | - | Yes |
| `ai_foundry_name` | Name prefix for AI Foundry resource | string | "aifoundry" | No |
| `sku_name` | SKU for AI services | string | "S0" | No |
| `disable_local_auth` | Disable API key authentication | bool | false | No |
| `gpt_deployment_name` | Name for GPT deployment | string | "gpt-4o" | No |
| `gpt_model_name` | GPT model to deploy | string | "gpt-4o" | No |
| `gpt_model_version` | Version of GPT model | string | "2024-11-20" | No |
| `project_display_name` | Display name for AI project | string | "AI Foundry Project" | No |
| `cosmosdb_name` | Name for CosmosDB account | string | "cosmosdb-ai-lz" | No |
| `cosmosdb_consistency_policy` | Consistency policy for CosmosDB | object | Session consistency | No |
| `cosmosdb_databases` | Database and container configuration | list(object) | AI data containers | No |

### Outputs

The module provides the following outputs:
- `resource_group_id`: ID of the created resource group
- `resource_group_name`: Name of the created resource group
- `ai_foundry_id`: ID of the AI Foundry resource
- `ai_foundry_name`: Name of the AI Foundry resource
- `gpt_deployment_id`: ID of the GPT deployment
- `ai_foundry_project_id`: ID of the AI project
- `cosmosdb_account_id`: ID of the CosmosDB account
- `cosmosdb_account_endpoint`: CosmosDB connection endpoint
- `cosmosdb_databases`: Information about created databases and containers

## Usage Examples

### Basic Deployment

Create a `terraform.tfvars` file:

```hcl
location            = "East US 2"
resource_group_name = "rg-ai-landing-zone"
```

### Advanced Configuration

```hcl
location              = "East US 2"
resource_group_name   = "rg-ai-prod"
ai_foundry_name      = "mycompany-ai"
disable_local_auth   = true  # Use Entra ID only
gpt_capacity         = 10    # Higher capacity for production
project_display_name = "Production AI Workloads"

# CosmosDB for AI data storage
cosmosdb_name = "mycompany-ai-data"
cosmosdb_consistency_policy = {
  consistency_level = "Strong"
}
cosmosdb_databases = [
  {
    name       = "production-ai-data"
    throughput = 1000
    containers = [
      {
        name               = "training-datasets"
        partition_key_path = "/datasetId"
        throughput        = 1000
      },
      {
        name               = "model-registry"
        partition_key_path = "/modelId"
        autoscale_settings = {
          max_throughput = 4000
        }
      }
    ]
  }
]
```

## Module Reference

This solution uses the AI Foundry module from the tjs-scripts repository via GitHub source. The module is maintained separately and can be found at:

```
github.com/tjsullivan1/tjs-scripts//terraform/modules/ai_foundry
```

## Security Considerations

- **Authentication**: The solution supports both API key and Entra ID authentication
- **Network Access**: Default configuration allows public network access; consider implementing private endpoints for production
- **Access Control**: Use Azure RBAC to control access to AI resources
- **Data Governance**: Implement appropriate data classification and protection policies

## Cost Optimization

- **SKU Selection**: Start with S0 SKU and scale based on usage
- **Model Capacity**: Begin with minimal capacity (1) and adjust based on demand
- **Resource Lifecycle**: Use Terraform to manage resource lifecycle and avoid orphaned resources

## Troubleshooting

### Common Issues

1. **Insufficient Permissions**: Ensure the deployment principal has the required Azure permissions
2. **Resource Name Conflicts**: AI service names must be globally unique; the module uses random suffixes to avoid conflicts
3. **Quota Limitations**: Check Azure subscription quotas for Cognitive Services in the target region

### Debugging

Enable Terraform debugging:
```bash
export TF_LOG=DEBUG
terraform apply
```

## Cleanup

To remove all deployed resources:

```bash
terraform destroy
```

## Contributing

This solution follows the repository's coding standards and best practices. See the main repository README for contribution guidelines.

## License

This project is licensed under the MIT License - see the main repository LICENSE file for details.