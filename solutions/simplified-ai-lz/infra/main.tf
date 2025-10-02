# Create Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "AI Landing Zone"
    Purpose     = "AI Foundry Resources"
    CreatedBy   = "Terraform"
  }
}

# Deploy AI Foundry using the module from GitHub
module "ai_foundry" {
  source = "github.com/tjsullivan1/tjs-scripts//terraform/modules/ai_foundry"

  # Pass the resource group object to the module
  resource_group_id = azurerm_resource_group.main.id
  location       = var.location

  # AI Foundry configuration
  ai_foundry_name    = var.ai_foundry_name
  sku_name          = var.sku_name
  disable_local_auth = var.disable_local_auth

  # GPT deployment configuration
  gpt_deployment_name = var.gpt_deployment_name
  gpt_model_name     = var.gpt_model_name
  gpt_model_version  = var.gpt_model_version
  gpt_sku_name       = var.gpt_sku_name
  gpt_capacity       = var.gpt_capacity

  # Project configuration
  project_name         = var.project_name
  project_display_name = var.project_display_name
  project_description  = var.project_description
}

# Deploy CosmosDB using the module from GitHub
module "cosmosdb" {
  source = "github.com/tjsullivan1/tjs-scripts//terraform/modules/cosmosdb"

  name                = var.cosmosdb_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  # CosmosDB configuration
  consistency_policy = var.cosmosdb_consistency_policy
  backup            = var.cosmosdb_backup
  capabilities      = var.cosmosdb_capabilities

  # Database and container configuration
  databases = var.cosmosdb_databases

  # Tagging
  tags = merge(
    {
      Environment = "AI Landing Zone"
      Purpose     = "AI Data Storage"
      CreatedBy   = "Terraform"
    },
    var.tags
  )
}