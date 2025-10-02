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

# Data Sources for Existing Network Resources
data "azurerm_virtual_network" "existing" {
  count = var.use_existing_network ? 1 : 0

  name                = var.existing_vnet_name
  resource_group_name = var.existing_vnet_resource_group_name != null ? var.existing_vnet_resource_group_name : azurerm_resource_group.main.name
}

data "azurerm_subnet" "existing" {
  count = var.use_existing_network ? 1 : 0

  name                 = var.existing_subnet_name
  virtual_network_name = var.existing_vnet_name
  resource_group_name  = var.existing_vnet_resource_group_name != null ? var.existing_vnet_resource_group_name : azurerm_resource_group.main.name
}

# Deploy AI Foundry using the module from GitHub
module "ai_foundry" {
  source = "github.com/tjsullivan1/tjs-scripts//terraform/modules/ai_foundry"

  # Pass the resource group object to the module
  resource_group_id = azurerm_resource_group.main.id
  location          = var.location

  # AI Foundry configuration
  ai_foundry_name    = var.ai_foundry_name
  sku_name           = var.sku_name
  disable_local_auth = var.disable_local_auth

  # GPT deployment configuration
  gpt_deployment_name = var.gpt_deployment_name
  gpt_model_name      = var.gpt_model_name
  gpt_model_version   = var.gpt_model_version
  gpt_sku_name        = var.gpt_sku_name
  gpt_capacity        = var.gpt_capacity

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
  backup             = var.cosmosdb_backup
  capabilities       = var.cosmosdb_capabilities

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

# Deploy CosmosDB MongoDB API using the module from GitHub
module "cosmosdb_mongo" {
  count = var.enable_mongodb ? 1 : 0

  source = "github.com/tjsullivan1/tjs-scripts//terraform/modules/cosmosdb-mongo"

  name                = var.cosmosdb_mongo_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  # MongoDB configuration
  consistency_policy = var.cosmosdb_mongo_consistency_policy
  backup             = var.cosmosdb_mongo_backup
  capabilities       = var.cosmosdb_mongo_capabilities

  # Network configuration
  public_network_access_enabled = var.cosmosdb_mongo_public_access
  ip_range_filter               = var.cosmosdb_mongo_ip_filter

  # Database and collection configuration
  databases = var.cosmosdb_mongo_databases

  # Tagging
  tags = merge(
    {
      Environment = "AI Landing Zone"
      Purpose     = "AI MongoDB Storage"
      CreatedBy   = "Terraform"
    },
    var.tags
  )
}