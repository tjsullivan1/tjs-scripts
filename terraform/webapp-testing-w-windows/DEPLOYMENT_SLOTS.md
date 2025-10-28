# Additional Deployment Slots Feature

## Overview

Enhanced the Windows Web Apps Terraform configuration to support multiple optional deployment slots beyond the default staging slot. This enables advanced deployment strategies including canary releases and dedicated QA environments.

## New Features Added

### 1. Additional Deployment Slot Types

#### Canary Slots
- **Purpose**: Canary releases with limited traffic for gradual rollouts
- **Variable**: `create_canary_slot` (default: false)
- **URL Pattern**: `{web_app_name}-canary.azurewebsites.net`
- **Use Case**: Test new features with a small subset of users before full rollout

#### QA Slots
- **Purpose**: Dedicated QA environment for quality assurance testing
- **Variable**: `create_qa_slot` (default: false)
- **URL Pattern**: `{web_app_name}-qa.azurewebsites.net`
- **Use Case**: Isolated environment for QA team testing

### 2. Variables Added

```hcl
variable "create_canary_slot" {
  description = "Whether to create a 'canary' deployment slot for each web app"
  type        = bool
  default     = false
}

variable "create_qa_slot" {
  description = "Whether to create a 'qa' deployment slot for each web app"
  type        = bool
  default     = false
}
```

### 3. Resources Added

- `azurerm_windows_web_app_slot.canary`: Canary deployment slots
- `azurerm_windows_web_app_slot.qa`: QA deployment slots

Both inherit all configuration from the main web app, including:
- Security settings (HTTPS-only, TLS 1.2, etc.)
- Application stack configuration
- Performance settings
- Default documents

### 4. Outputs Added

#### Canary Slot Outputs
- `web_app_canary_slot_names`: Array of canary slot names
- `web_app_canary_slot_urls`: Array of canary slot URLs
- `web_app_canary_slot_ids`: Array of canary slot resource IDs

#### QA Slot Outputs
- `web_app_qa_slot_names`: Array of QA slot names
- `web_app_qa_slot_urls`: Array of QA slot URLs
- `web_app_qa_slot_ids`: Array of QA slot resource IDs

## Usage Examples

### Enable All Slots
```hcl
web_app_count       = 2
create_staging_slot = true
create_canary_slot  = true
create_qa_slot      = true
dotnet_version      = "v6.0"
```

### Canary-Only Setup
```hcl
web_app_count       = 1
create_staging_slot = true
create_canary_slot  = true
create_qa_slot      = false
dotnet_version      = "v8.0"
```

### Production-Only (No Slots)
```hcl
web_app_count       = 5
create_staging_slot = false
create_canary_slot  = false
create_qa_slot      = false
dotnet_version      = "v7.0"
```

## Deployment Strategies

### 1. Blue-Green Deployment (Staging Only)
1. Deploy to staging slot
2. Test thoroughly
3. Swap to production

### 2. Canary Release Strategy
1. Deploy to staging for initial testing
2. Deploy to canary for limited user exposure
3. Monitor metrics and gradually increase traffic
4. Swap to production when stable

### 3. Multi-Environment Testing
1. Development: Main web app
2. QA Testing: QA slot
3. Staging Validation: Staging slot
4. Canary Testing: Canary slot
5. Production: Slot swap

## Cost Considerations

- **Additional Slots**: Each slot incurs minimal additional cost (~10% of main app)
- **Resource Sharing**: All slots share the same App Service Plan
- **Optional Nature**: Slots are opt-in, so no cost impact unless enabled
- **Recommendation**: Enable only the slots you need for your deployment strategy

## Configuration Management

### Slot-Specific Settings
Each slot includes a `SLOT_NAME` app setting for identification:
- Staging: `SLOT_NAME = "staging"`
- Canary: `SLOT_NAME = "canary"`
- QA: `SLOT_NAME = "qa"`

### Lifecycle Management
All slots include lifecycle rules to ignore deployment-related changes:
```hcl
lifecycle {
  ignore_changes = [
    app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    zip_deploy_file
  ]
}
```

## Best Practices

1. **Start Simple**: Begin with staging slots only, add others as needed
2. **Monitor Usage**: Use Application Insights to track slot performance
3. **Automate Swaps**: Use Azure CLI or ARM templates for slot swaps
4. **Test Strategy**: Define clear testing criteria for each slot
5. **Cost Management**: Regularly review which slots are actively used

## Validation

- ✅ All configurations pass `terraform validate`
- ✅ No syntax or structural errors
- ✅ Proper resource dependencies maintained
- ✅ Outputs correctly reference new resources
- ✅ Documentation updated with examples and best practices

## Future Enhancements

Potential future additions:
- Pre-production slot (between staging and production)
- A/B testing slots with traffic routing rules
- Integration with Azure DevOps deployment pipelines
- Automated slot swap based on health checks