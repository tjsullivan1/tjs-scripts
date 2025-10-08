# Azure Web Apps Terraform Configuration

This Terraform configuration deploys multiple Azure Linux Web Apps with configurable count and settings.

## Architecture

- **Resource Group**: Uses existing resource group
- **App Service Plan**: Uses existing App Service Plan  
- **Web Apps**: Deploys 1-20 Linux Web Apps with configurable runtime stacks

## Features

- ✅ Deploy multiple web apps with a single configuration
- ✅ Configurable count (1-20 web apps)
- ✅ Support for .NET, Node.js, Python runtime stacks OR Docker containers
- ✅ Docker support with public and private registry authentication
- ✅ Deployment slots (prod slot) for blue-green deployments
- ✅ Security best practices (HTTPS-only, TLS 1.2, secure FTP)
- ✅ Performance optimizations (HTTP/2, 64-bit workers)
- ✅ Comprehensive tagging
- ✅ Validation rules for inputs
- ✅ Detailed outputs for integration

## Prerequisites

- Azure CLI installed and authenticated
- Terraform >= 1.5
- Existing Resource Group
- Existing App Service Plan

## Quick Start

1. **Clone and navigate to the directory**:
   ```bash
   cd /workspaces/tjs-scripts/terraform/tmp
   ```

2. **Copy the example variables file**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit `terraform.tfvars`** with your specific values:
   ```hcl
   # Number of web apps to deploy
   web_app_count = 5
   
   # Runtime stack (choose one)
   dotnet_version = "8.0"
   # node_version = "18-lts" 
   # python_version = "3.11"
   
   # Other settings...
   ```

4. **Initialize and apply**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Configuration

### Required Variables

- `resource_group_name`: Name of existing resource group
- `app_service_plan_name`: Name of existing App Service Plan

### Key Variables

| Variable | Description | Default | Validation |
|----------|-------------|---------|------------|
| `web_app_count` | Number of web apps to deploy | 1 | 1-20 |
| `web_app_name_prefix` | Prefix for web app names | "wa-harness" | 1-40 chars, lowercase |
| `app_service_plan_sku` | App Service Plan SKU | "B1" | Valid Azure SKUs |
| `create_prod_slot` | Create prod deployment slot | true | Boolean |
| `docker_image` | Docker image name | "" | Optional |
| `dotnet_version` | .NET version | "" | Optional |
| `node_version` | Node.js version | "" | Optional |
| `python_version` | Python version | "" | Optional |

### Web App Naming

Web apps are named using the pattern: `{web_app_name_prefix}-{count}`
Deployment slots are named: `{web_app_name}-{slot_name}`

Examples:
- `web_app_count = 3` → `wa-harness-1`, `wa-harness-2`, `wa-harness-3`
- With prod slots → `wa-harness-1/prod`, `wa-harness-2/prod`, `wa-harness-3/prod`
- `web_app_name_prefix = "myapp"` → `myapp-1`, `myapp-2`, etc.

### Deployment Slots

Each web app can optionally include a "prod" deployment slot:
- **Purpose**: Enable blue-green deployments and staging
- **Configuration**: Controlled by `create_prod_slot` variable (default: true)
- **Inheritance**: Slots inherit configuration from the main web app
- **URLs**: Accessible at `{web_app_name}-{slot}.azurewebsites.net`

## Outputs

| Output | Description |
|--------|-------------|
| `web_app_names` | Array of web app names |
| `web_app_urls` | Array of web app default hostnames |
| `web_app_ids` | Array of web app resource IDs |
| `web_app_prod_slot_names` | Array of prod slot names (if created) |
| `web_app_prod_slot_urls` | Array of prod slot URLs (if created) |
| `web_app_prod_slot_ids` | Array of prod slot resource IDs (if created) |
| `web_app_outbound_ip_addresses` | Outbound IP addresses |
| `service_plan_id` | App Service Plan resource ID |

## Security Features

- **HTTPS Only**: Enforced by default
- **TLS 1.2**: Minimum version required
- **Secure FTP**: FTPS-only mode
- **Authentication**: Basic auth disabled for FTP/WebDeploy
- **HTTP/2**: Enabled for better performance

## Cost Considerations

- **App Service Plan**: Shared across all web apps (cost-effective)
- **Web Apps**: Each app incurs minimal additional cost
- **Scaling**: Use `web_app_count` to scale horizontally

## Examples

### Deploy 5 .NET Web Apps
```hcl
web_app_count     = 5
dotnet_version    = "8.0"
web_app_name_prefix = "dotnet-app"
```

### Deploy 3 Node.js Web Apps
```hcl
web_app_count     = 3
node_version      = "18-lts"
web_app_name_prefix = "node-app"
```

### Deploy Single Python Web App
```hcl
web_app_count     = 1
python_version    = "3.11"
web_app_name_prefix = "python-app"
```

### Deploy Docker-based Web Apps

**Nginx Web Server:**
```hcl
web_app_count = 3
docker_image  = "nginx:latest"
web_app_name_prefix = "nginx-app"
```

**Apache HTTP Server:**
```hcl
web_app_count = 2
docker_image  = "httpd:alpine"
web_app_name_prefix = "apache-app"
```

**Custom Node.js App:**
```hcl
web_app_count = 1
docker_image  = "node:18-alpine"
web_app_name_prefix = "custom-node-app"
```

**Private Registry Example:**
```hcl
web_app_count = 1
docker_image  = "myregistry.azurecr.io/myapp:latest"
docker_registry_url = "https://myregistry.azurecr.io"
docker_registry_username = "myregistry"
docker_registry_password = "your-password"
```

### Deployment Slot Examples

**Enable prod slots (default):**
```hcl
web_app_count = 2
create_prod_slot = true
docker_image = "nginx:latest"
```

**Disable prod slots:**
```hcl
web_app_count = 3
create_prod_slot = false
dotnet_version = "8.0"
```

**Blue-Green Deployment Workflow:**
1. Deploy to main slot: `wa-harness-1.azurewebsites.net`
2. Test in prod slot: `wa-harness-1-prod.azurewebsites.net`
3. Swap slots when ready using Azure Portal or CLI

## Cleanup

To remove all resources:
```bash
terraform destroy
```

## Troubleshooting

### Common Issues

1. **Resource Group doesn't exist**
   - Ensure the resource group exists before running Terraform
   - Check `resource_group_name` variable

2. **App Service Plan doesn't exist**
   - Verify the App Service Plan exists in the specified resource group
   - Check `app_service_plan_name` variable

3. **Name conflicts**
   - Web app names must be globally unique
   - Modify `web_app_name_prefix` if names are taken

4. **SKU mismatch**
   - Ensure `always_on` is compatible with your App Service Plan SKU
   - Free tier doesn't support `always_on = true`

### Validation

Run these commands to validate your configuration:
```bash
terraform validate
terraform plan
```

## Contributing

This configuration follows the repository's Terraform guidelines:
- Uses latest AzureRM provider (v4.40+)
- Implements proper variable validation
- Includes comprehensive documentation
- Follows Azure naming conventions
- Implements security best practices

---

For more examples and patterns, see the [tjs-scripts repository](https://github.com/tjsullivan1/tjs-scripts).