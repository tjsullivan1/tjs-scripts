# main.tf
locals {
}

resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  name     = random_pet.rg_name.id
  location = var.resource_group_location

  # ignore changes to tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "random_string" "acrname" {
  length  = 13
  lower   = true
  numeric = false
  special = false
  upper   = false
}

resource "azurerm_resource_group" "rg2" {
  provider = azurerm.secondary
  name     = "${random_pet.rg_name.id}-2"
  location = var.resource_group_location

  # ignore changes to tags
  lifecycle {
    ignore_changes = [tags]
  }
}

# create a virtual network in the primary subscription. Address space should be 192.168.100.0/24
# it should contain a subnet named "default" with that address space
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${random_pet.rg_name.id}"
  address_space       = ["192.168.100.0/24"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# create a subnet for the virtual network
resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["192.168.100.0/24"]
}

# create a virtual network in the secondary subscription. Address space should be 192.168.101.0/24
# it should contain a subnet named "default" with that address space
resource "azurerm_virtual_network" "vnet2" {
  provider            = azurerm.secondary
  name                = "vnet-secondary-${random_pet.rg_name.id}"
  address_space       = ["192.168.101.0/24"]
  location            = azurerm_resource_group.rg2.location
  resource_group_name = azurerm_resource_group.rg2.name
}

# create a subnet for the virtual network
resource "azurerm_subnet" "subnet2" {
  provider             = azurerm.secondary
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg2.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["192.168.101.0/24"]
  }

# peer the virtual networks
resource "azurerm_virtual_network_peering" "vnet1_to_vnet2" {
  name                         = "vnet1-to-vnet2"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# create the inverse peering connection
resource "azurerm_virtual_network_peering" "vnet2_to_vnet1" {
  provider = azurerm.secondary
  name                         = "vnet2-to-vnet1"
  resource_group_name          = azurerm_resource_group.rg2.name
  virtual_network_name         = azurerm_virtual_network.vnet2.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
}

# create an AKS cluster in the primary subscription
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${random_pet.rg_name.id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-${random_pet.rg_name.id}"
  node_resource_group = "aks-${random_pet.rg_name.id}-nodes"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D4s_v4"
    vnet_subnet_id = azurerm_subnet.subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
  }

}

# create an Azure Container Registry in the secondary subscription
resource "azurerm_container_registry" "acr" {
  provider            = azurerm.secondary
  name                = "acr${random_string.acrname.result}"
  resource_group_name = azurerm_resource_group.rg2.name
  location            = azurerm_resource_group.rg2.location
  sku                 = "Premium"
  admin_enabled       = false
  public_network_access_enabled = false
}

# the above AKS cluster should have AcrPull role on the container registry
resource "azurerm_role_assignment" "aks_acr_role" {
  provider =  azurerm.secondary
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# Create the private dns zone for acr_dns
resource "azurerm_private_dns_zone" "acr_dns" {
  provider =  azurerm.secondary
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.rg2.name
}

# create a private endpoint for the container registry in the secondary subscription vnet
# it should have DNS enabled
resource "azurerm_private_endpoint" "acr_endpoint" {
  provider            = azurerm.secondary
  name                = "acr-endpoint"
  location            = azurerm_resource_group.rg2.location
  resource_group_name = azurerm_resource_group.rg2.name
  subnet_id           = azurerm_subnet.subnet2.id

  private_service_connection {
    is_manual_connection = false
    name                           = "acr-endpoint-connection"
    private_connection_resource_id = azurerm_container_registry.acr.id
    subresource_names              = ["registry"]
  }

  # enable DNS for the private endpoint
  private_dns_zone_group {
    name                = "acr-endpoint-dns"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr_dns.id]
  }
}

# link the private dns zone to the virtual network in the primary subscription
resource "azurerm_private_dns_zone_virtual_network_link" "acr_dns_link" {
  provider = azurerm.secondary
  name                  = "acr-dns-link"
  resource_group_name   = azurerm_resource_group.rg2.name
  private_dns_zone_name = azurerm_private_dns_zone.acr_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}


resource "azurerm_private_dns_zone_virtual_network_link" "acr_dns_link_2" {
  provider = azurerm.secondary
  name                  = "acr-dns-link-aks-vnet"
  resource_group_name   = azurerm_resource_group.rg2.name
  private_dns_zone_name = azurerm_private_dns_zone.acr_dns.name
  virtual_network_id    = azurerm_virtual_network.vnet2.id
}