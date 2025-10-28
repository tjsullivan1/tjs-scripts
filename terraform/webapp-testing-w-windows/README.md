# Azure Windows Web Apps Terraform Configuration

This Terraform configuration deploys multiple Azure Windows Web Apps with configurable count and settings.

## Architecture

- **Resource Group**: Uses existing resource group
- **App Service Plan**: Windows-based App Service Plan with P2v3 SKU
- **Web Apps**: Deploys 1-20 Windows Web Apps with configurable runtime stacks

## Features

- ✅ Deploy multiple Windows web apps with a single configuration
- ✅ Configurable count (1-20 web apps)
- ✅ Support for .NET and Node.js runtime stacks
- ✅ Multiple deployment slots (staging, canary, QA) for advanced deployment strategies
- ✅ Security best practices (HTTPS-only, TLS 1.2, secure FTP)
- ✅ Performance optimizations (HTTP/2, 64-bit workers)
- ✅ Comprehensive tagging
- ✅ Validation rules for inputs
- ✅ Detailed outputs for integration

## Prerequisites

- Azure CLI installed and authenticated
- Terraform >= 1.5
- Existing Resource Group

## Quick Start

1. **Clone and navigate to the directory**:
   ```bash
   cd /workspaces/tjs-scripts/terraform/webapp-testing-w-windows
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
   dotnet_version = "v6.0"  # Options: v6.0, v7.0, v8.0
   # node_version = "18-lts"  # Options: 18-lts, 20-lts
   
   # Deployment slots (optional)
   create_staging_slot = true
   create_canary_slot  = false
   create_qa_slot      = false
   
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

### Key Variables

| Variable | Description | Default | Validation |
|----------|-------------|---------|------------|
| `web_app_count` | Number of web apps to deploy | 1 | 1-20 |
| `web_app_name_prefix` | Prefix for web app names | "wa-harness" | 1-40 chars, lowercase |
| `create_staging_slot` | Create staging deployment slot | true | Boolean |
| `create_canary_slot` | Create canary deployment slot | false | Boolean |
| `create_qa_slot` | Create QA deployment slot | false | Boolean |
| `dotnet_version` | .NET version | "v6.0" | v6.0, v7.0, v8.0 |
| `node_version` | Node.js version | "" | 18-lts, 20-lts |

### Web App Naming

Web apps are named using the pattern: `{web_app_name_prefix}-{count}`
Deployment slots are named: `{web_app_name}-{slot_name}`

Examples:
- `web_app_count = 3` → `wa-harness-1`, `wa-harness-2`, `wa-harness-3`
- With staging slots → `wa-harness-1/staging`, `wa-harness-2/staging`, `wa-harness-3/staging`
- `web_app_name_prefix = "myapp"` → `myapp-1`, `myapp-2`, etc.

### Deployment Slots

Each web app supports multiple optional deployment slots for advanced deployment strategies:

#### Staging Slots (Default: Enabled)
- **Purpose**: Primary deployment slot for testing before production
- **Configuration**: Controlled by `create_staging_slot` variable (default: true)
- **URLs**: Accessible at `{web_app_name}-staging.azurewebsites.net`

#### Canary Slots (Optional)
- **Purpose**: Canary releases with limited traffic for gradual rollouts
- **Configuration**: Controlled by `create_canary_slot` variable (default: false)
- **URLs**: Accessible at `{web_app_name}-canary.azurewebsites.net`

#### QA Slots (Optional)
- **Purpose**: Dedicated QA environment for quality assurance testing
- **Configuration**: Controlled by `create_qa_slot` variable (default: false)
- **URLs**: Accessible at `{web_app_name}-qa.azurewebsites.net`

**Common Features:**
- **Inheritance**: All slots inherit configuration from the main web app
- **Independent Settings**: Each slot can have custom app settings
- **Slot Swapping**: Supports Azure's slot swap functionality for zero-downtime deployments

## Outputs

| Output | Description |
|--------|-------------|
| `web_app_names` | Array of web app names |
| `web_app_urls` | Array of web app default hostnames |
| `web_app_ids` | Array of web app resource IDs |
| `web_app_staging_slot_names` | Array of staging slot names (if created) |
| `web_app_staging_slot_urls` | Array of staging slot URLs (if created) |
| `web_app_staging_slot_ids` | Array of staging slot resource IDs (if created) |
| `web_app_canary_slot_names` | Array of canary slot names (if created) |
| `web_app_canary_slot_urls` | Array of canary slot URLs (if created) |
| `web_app_canary_slot_ids` | Array of canary slot resource IDs (if created) |
| `web_app_qa_slot_names` | Array of QA slot names (if created) |
| `web_app_qa_slot_urls` | Array of QA slot URLs (if created) |
| `web_app_qa_slot_ids` | Array of QA slot resource IDs (if created) |
| `web_app_outbound_ip_addresses` | Outbound IP addresses |
| `service_plan_id` | App Service Plan resource ID |

## Security Features

- **HTTPS Only**: Enforced by default
- **TLS 1.2**: Minimum version required
- **Secure FTP**: FTPS-only mode
- **Authentication**: Basic auth disabled for FTP/WebDeploy
- **HTTP/2**: Enabled for better performance

## Cost Considerations

- **App Service Plan**: P2v3 SKU, shared across all web apps (cost-effective)
- **Web Apps**: Each app incurs minimal additional cost
- **Scaling**: Use `web_app_count` to scale horizontally

## Examples

### Deploy 5 .NET Web Apps
```hcl
web_app_count       = 5
dotnet_version      = "v6.0"
web_app_name_prefix = "dotnet-app"
```

### Deploy 3 Node.js Web Apps
```hcl
web_app_count       = 3
node_version        = "18-lts"
dotnet_version      = ""  # Disable .NET
web_app_name_prefix = "node-app"
```
web_app_name_prefix = "nginx-app"
```
### Deployment Slot Examples

**Enable staging slots only (default):**
```hcl
web_app_count        = 2
create_staging_slot  = true
create_canary_slot   = false
create_qa_slot       = false
dotnet_version       = "v6.0"
```

**Enable all deployment slots:**
```hcl
web_app_count        = 1
create_staging_slot  = true
create_canary_slot   = true
create_qa_slot       = true
dotnet_version       = "v8.0"
```

**Canary deployment setup:**
```hcl
web_app_count        = 2
create_staging_slot  = true   # For initial testing
create_canary_slot   = true   # For canary releases
create_qa_slot       = false
dotnet_version       = "v7.0"
```

**Disable all deployment slots:**
```hcl
web_app_count        = 3
create_staging_slot  = false
create_canary_slot   = false
create_qa_slot       = false
dotnet_version       = "v8.0"
```

**Advanced Deployment Workflows:**

**Blue-Green Deployment (Staging):**
1. Deploy to main slot: `wa-harness-1.azurewebsites.net`
2. Test in staging slot: `wa-harness-1-staging.azurewebsites.net`
3. Swap slots when ready using Azure Portal or CLI

**Canary Release Strategy:**
1. Deploy to staging: `wa-harness-1-staging.azurewebsites.net`
2. Deploy to canary: `wa-harness-1-canary.azurewebsites.net` (limited traffic)
3. Monitor metrics and gradually increase traffic
4. Swap to production when stable

**Multi-Environment Testing:**
1. Development testing: Main web app
2. QA testing: `wa-harness-1-qa.azurewebsites.net`
3. Staging validation: `wa-harness-1-staging.azurewebsites.net`
4. Canary deployment: `wa-harness-1-canary.azurewebsites.net`
5. Production release via slot swap

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

2. **Web App naming conflicts**
   - Web app names must be globally unique across Azure
   - Try a different `web_app_name_prefix` value

3. **Invalid runtime versions**
   - Check that `dotnet_version` uses valid values (v6.0, v7.0, v8.0)
   - Check that `node_version` uses valid values (18-lts, 20-lts)

4. **Permission issues**
   - Ensure you have Contributor access to the resource group
   - Verify Azure CLI authentication: `az account show`

### Validation Commands
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