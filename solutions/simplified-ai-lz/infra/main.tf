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

data "azurerm_subnet" "pe" {
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

# Private Endpoints
# Private Endpoint for CosmosDB SQL API
resource "azurerm_private_endpoint" "cosmosdb_sql" {
  count = var.enable_private_endpoints ? 1 : 0

  name                = "${var.cosmosdb_name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = data.azurerm_subnet.pe[0].id

  private_service_connection {
    name                           = "${var.cosmosdb_name}-psc"
    private_connection_resource_id = module.cosmosdb.cosmosdb_account_id
    is_manual_connection           = false
    subresource_names              = ["Sql"]
  }

  tags = merge(
    {
      Environment = "AI Landing Zone"
      Purpose     = "CosmosDB Private Access"
      CreatedBy   = "Terraform"
    },
    var.tags
  )
}

# Private Endpoint for CosmosDB MongoDB API
resource "azurerm_private_endpoint" "cosmosdb_mongo" {
  count = var.enable_private_endpoints && var.enable_mongodb ? 1 : 0

  name                = "${var.cosmosdb_mongo_name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = data.azurerm_subnet.pe[0].id

  private_service_connection {
    name                           = "${var.cosmosdb_mongo_name}-psc"
    private_connection_resource_id = module.cosmosdb_mongo[0].cosmosdb_account_id
    is_manual_connection           = false
    subresource_names              = ["MongoDB"]
  }

  tags = merge(
    {
      Environment = "AI Landing Zone"
      Purpose     = "CosmosDB MongoDB Private Access"
      CreatedBy   = "Terraform"
    },
    var.tags
  )
}

# Private Endpoint for AI Foundry (Cognitive Services)
resource "azurerm_private_endpoint" "ai_foundry" {
  count = var.enable_private_endpoints ? 1 : 0

  name                = "${var.ai_foundry_name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = data.azurerm_subnet.pe[0].id

  private_service_connection {
    name                           = "${var.ai_foundry_name}-psc"
    private_connection_resource_id = module.ai_foundry.ai_foundry_id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  tags = merge(
    {
      Environment = "AI Landing Zone"
      Purpose     = "AI Foundry Private Access"
      CreatedBy   = "Terraform"
    },
    var.tags
  )
}

# Private DNS Zones
# Private DNS Zone for CosmosDB SQL API
resource "azurerm_private_dns_zone" "cosmos_sql" {
  count = var.enable_private_endpoints && var.create_private_dns_zones && var.private_dns_zone_ids.cosmos_sql == null ? 1 : 0

  name                = "privatelink.documents.azure.com"
  resource_group_name = azurerm_resource_group.main.name

  tags = merge(
    {
      Environment = "AI Landing Zone"
      Purpose     = "CosmosDB SQL Private DNS"
      CreatedBy   = "Terraform"
    },
    var.tags
  )
}

# Private DNS Zone for CosmosDB MongoDB API
resource "azurerm_private_dns_zone" "cosmos_mongo" {
  count = var.enable_private_endpoints && var.enable_mongodb && var.create_private_dns_zones && var.private_dns_zone_ids.cosmos_mongo == null ? 1 : 0

  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = azurerm_resource_group.main.name

  tags = merge(
    {
      Environment = "AI Landing Zone"
      Purpose     = "CosmosDB MongoDB Private DNS"
      CreatedBy   = "Terraform"
    },
    var.tags
  )
}

# Private DNS Zone for Cognitive Services
resource "azurerm_private_dns_zone" "cognitive_services" {
  count = var.enable_private_endpoints && var.create_private_dns_zones && var.private_dns_zone_ids.cognitive_services == null ? 1 : 0

  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = azurerm_resource_group.main.name

  tags = merge(
    {
      Environment = "AI Landing Zone"
      Purpose     = "Cognitive Services Private DNS"
      CreatedBy   = "Terraform"
    },
    var.tags
  )
}

# Private DNS Zone Virtual Network Links
resource "azurerm_private_dns_zone_virtual_network_link" "cosmos_sql" {
  count = var.enable_private_endpoints && (var.create_private_dns_zones || var.private_dns_zone_ids.cosmos_sql != null) ? 1 : 0

  name                  = "${var.cosmosdb_name}-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = var.private_dns_zone_ids.cosmos_sql != null ? data.azurerm_private_dns_zone.cosmos_sql[0].name : azurerm_private_dns_zone.cosmos_sql[0].name
  virtual_network_id    = data.azurerm_virtual_network.existing[0].id
  registration_enabled  = false

  tags = merge(
    {
      Environment = "AI Landing Zone"
      Purpose     = "CosmosDB SQL DNS Link"
      CreatedBy   = "Terraform"
    },
    var.tags
  )
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmos_mongo" {
  count = var.enable_private_endpoints && var.enable_mongodb && (var.create_private_dns_zones || var.private_dns_zone_ids.cosmos_mongo != null) ? 1 : 0

  name                  = "${var.cosmosdb_mongo_name}-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = var.private_dns_zone_ids.cosmos_mongo != null ? data.azurerm_private_dns_zone.cosmos_mongo[0].name : azurerm_private_dns_zone.cosmos_mongo[0].name
  virtual_network_id    = data.azurerm_virtual_network.existing[0].id
  registration_enabled  = false

  tags = merge(
    {
      Environment = "AI Landing Zone"
      Purpose     = "CosmosDB MongoDB DNS Link"
      CreatedBy   = "Terraform"
    },
    var.tags
  )
}

resource "azurerm_private_dns_zone_virtual_network_link" "cognitive_services" {
  count = var.enable_private_endpoints && (var.create_private_dns_zones || var.private_dns_zone_ids.cognitive_services != null) ? 1 : 0

  name                  = "${var.ai_foundry_name}-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = var.private_dns_zone_ids.cognitive_services != null ? data.azurerm_private_dns_zone.cognitive_services[0].name : azurerm_private_dns_zone.cognitive_services[0].name
  virtual_network_id    = data.azurerm_virtual_network.existing[0].id
  registration_enabled  = false

  tags = merge(
    {
      Environment = "AI Landing Zone"
      Purpose     = "Cognitive Services DNS Link"
      CreatedBy   = "Terraform"
    },
    var.tags
  )
}

# Data sources for existing private DNS zones (when using existing zones)
data "azurerm_private_dns_zone" "cosmos_sql" {
  count = var.enable_private_endpoints && var.private_dns_zone_ids.cosmos_sql != null ? 1 : 0

  name                = "privatelink.documents.azure.com"
  resource_group_name = split("/", var.private_dns_zone_ids.cosmos_sql)[4]
}

data "azurerm_private_dns_zone" "cosmos_mongo" {
  count = var.enable_private_endpoints && var.enable_mongodb && var.private_dns_zone_ids.cosmos_mongo != null ? 1 : 0

  name                = "privatelink.mongo.cosmos.azure.com"
  resource_group_name = split("/", var.private_dns_zone_ids.cosmos_mongo)[4]
}

data "azurerm_private_dns_zone" "cognitive_services" {
  count = var.enable_private_endpoints && var.private_dns_zone_ids.cognitive_services != null ? 1 : 0

  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = split("/", var.private_dns_zone_ids.cognitive_services)[4]
}