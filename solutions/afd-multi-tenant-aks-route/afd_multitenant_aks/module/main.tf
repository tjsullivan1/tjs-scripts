# main.tf
locals {
}

resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  name     =  "${random_pet.rg_name.id}-${var.indicator_suffix}"
  location = var.resource_group_location

  # ignore changes to tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_kubernetes_cluster" "cluster1" {
  name                = "aks-${random_pet.rg_name.id}-${var.indicator_suffix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-${random_pet.rg_name.id}-${var.indicator_suffix}"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D4_v5"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Production"
  }
}


data "azurerm_dns_zone" "domain" {
  name                = var.domain_name
  resource_group_name = var.zone_resource_group
}

resource "azurerm_dns_a_record" "aks-ingress" {
  name                = var.ingress_name
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = data.azurerm_dns_zone.domain.resource_group_name
  ttl                 = 300
  records             = [ "${var.ingress_ip}" ]
}

resource "azurerm_cdn_frontdoor_profile" "afd" {
  name                = "afd-${random_pet.rg_name.id}-${var.indicator_suffix}"
  resource_group_name = azurerm_resource_group.rg.name
  sku_name                 = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_endpoint" "ep1" {
  name                     = "ep1-${random_pet.rg_name.id}-${var.indicator_suffix}"
  cdn_frontdoor_profile_id =  azurerm_cdn_frontdoor_profile.afd.id
}

resource "azurerm_cdn_frontdoor_origin_group" "o1" {
  name                     = "${var.resource_group_location}-cluster"
  cdn_frontdoor_profile_id =  azurerm_cdn_frontdoor_profile.afd.id

  load_balancing {
  }
}

resource "azurerm_cdn_frontdoor_origin" "o1" {
  name                          = "primary-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.o1.id
  enabled                       = true

  certificate_name_check_enabled = false
  host_name                      = "${var.ingress_name}.${var.domain_name}"
  http_port                      = 80
  https_port                     = 443
  priority                       = 1
  weight                         = 1

}

resource "azurerm_cdn_frontdoor_origin" "o2" {
  name                          = "fallback-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.o1.id
  enabled                       = true

  certificate_name_check_enabled = false
  host_name                      = "${var.secondary_ingress_name}.${var.domain_name}"
  http_port                      = 80
  https_port                     = 443
  priority                       = 5
  weight                         = 1

}

resource "azurerm_cdn_frontdoor_custom_domain" "subdomain1" {
  name                     = var.custom_subdomain_names.0
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
  dns_zone_id              = data.azurerm_dns_zone.domain.id
  host_name                = "${var.custom_subdomain_names.0}.${var.domain_name}"

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_cdn_frontdoor_custom_domain" "subdomain2" {
  name                     = var.custom_subdomain_names.1
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd.id
  dns_zone_id              = data.azurerm_dns_zone.domain.id
  host_name                = "${var.custom_subdomain_names.1}.${var.domain_name}"

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_dns_txt_record" "subdomain1" {
  name                = join(".", ["_dnsauth", "${var.custom_subdomain_names.0}"])
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = data.azurerm_dns_zone.domain.resource_group_name
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.subdomain1.validation_token
  }
}

resource "azurerm_dns_cname_record" "subdomain1" {
  name = var.custom_subdomain_names.0
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = data.azurerm_dns_zone.domain.resource_group_name
  ttl                 = 3600

  record =  azurerm_cdn_frontdoor_endpoint.ep1.host_name
}
  
resource "azurerm_dns_txt_record" "subdomain2" {
  name                = join(".", ["_dnsauth", "${var.custom_subdomain_names.1}"])
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = data.azurerm_dns_zone.domain.resource_group_name
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.subdomain2.validation_token
  }
}

resource "azurerm_dns_cname_record" "subdoamin2" {
  name = var.custom_subdomain_names.1
  zone_name           = data.azurerm_dns_zone.domain.name
  resource_group_name = data.azurerm_dns_zone.domain.resource_group_name
  ttl                 = 3600

  record =  azurerm_cdn_frontdoor_endpoint.ep1.host_name
  
}

resource "azurerm_cdn_frontdoor_route" "route1" {
  name                          = "default-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.ep1.id
  cdn_frontdoor_custom_domain_ids = [ azurerm_cdn_frontdoor_custom_domain.subdomain1.id, azurerm_cdn_frontdoor_custom_domain.subdomain2.id ]
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.o1.id
  cdn_frontdoor_origin_ids      = []
  cdn_frontdoor_rule_set_ids    = []
  enabled                       = true

  forwarding_protocol    = "HttpOnly"
  https_redirect_enabled = false
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  link_to_default_domain          = true
}