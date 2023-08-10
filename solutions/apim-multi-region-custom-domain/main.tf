locals {
  front_door_profile_name      = "afd-apims"
  front_door_endpoint_name     = "afd-${lower(random_id.front_door_endpoint_name.hex)}"
  front_door_origin_group_name = "api-management"
  front_door_origin_name       = "primary-endpoint"
  front_door_origin_name_2     = "secondary-endpoint"
  front_door_route_name        = "apim-routes"
}

resource "random_id" "front_door_endpoint_name" {
  byte_length = 8
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

resource "random_string" "azurerm_api_management_name" {
  length  = 13
  lower   = true
  numeric = false
  special = false
  upper   = false
}

resource "azurerm_api_management" "api" {
  name                = "apiservice${random_string.azurerm_api_management_name.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_email     = var.publisher_email
  publisher_name      = var.publisher_name
  sku_name            = "${var.sku}_${var.sku_count}"
  # Add an additional location to the API Management service in centralus
  additional_location {
    location = "centralus"
  }
}

# Add an API called "test" to the API Management service
# give it the endpoint /test
# have it mock responses
resource "azurerm_api_management_api" "test" {
  name                  = "test"
  display_name          = "Test API"
  path                  = "test"
  protocols             = ["https"]
  revision              = "1"
  subscription_required = true

  api_management_name = azurerm_api_management.api.name
  resource_group_name = azurerm_resource_group.rg.name
}

# add the API operation for a get request
resource "azurerm_api_management_api_operation" "get_test" {
  operation_id        = "get-test"
  display_name        = "get-test"
  api_name            = azurerm_api_management_api.test.name
  api_management_name = azurerm_api_management.api.name
  resource_group_name = azurerm_resource_group.rg.name
  method              = "GET"
  url_template        = "/test"
  description         = "Get test"
  # mock response
  response {
    status_code = 200
    representation {
      content_type = "application/json"
      example {
        name  = "default"
        value = jsonencode({ "sampleField" : "test1" })
      }
    }
  }

  response {
    status_code = 400
    representation {
      content_type = "application/json"
      example {
        name = "default"
      }
    }
  }

  response {
    status_code = 201
    representation {
      content_type = "application/json"
      example {
        name  = "default"
        value = jsonencode({ "sampleField" : "created" })
      }
    }
  }
}

# add the policy to the get operation
resource "azurerm_api_management_api_operation_policy" "get_test_policy" {
  api_name            = azurerm_api_management_api.test.name
  api_management_name = azurerm_api_management.api.name
  resource_group_name = azurerm_resource_group.rg.name
  operation_id        = azurerm_api_management_api_operation.get_test.operation_id
  xml_content         = <<XML
  <policies>
    <inbound>
        <base />
        <choose>
            <when condition="@("West US".Equals(context.Deployment.Region, StringComparison.OrdinalIgnoreCase))">
              <set-body>West US</set-body>
            </when>
            <when condition="@("East US".Equals(context.Deployment.Region, StringComparison.OrdinalIgnoreCase))">
              <mock-response status-code="200" content-type="application/json" />
            </when>
            <when condition="@("Central US".Equals(context.Deployment.Region, StringComparison.OrdinalIgnoreCase))">
              <mock-response status-code="201" content-type="application/json" />
            </when>
            <otherwise>
              <mock-response status-code="400" content-type="application/json" />
            </otherwise>
        </choose>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
XML
}

resource "azurerm_cdn_frontdoor_profile" "my_front_door" {
  name                = local.front_door_profile_name
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = var.front_door_sku_name
}

resource "azurerm_cdn_frontdoor_endpoint" "my_endpoint" {
  name                     = local.front_door_endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
}

resource "azurerm_cdn_frontdoor_origin_group" "my_origin_group" {
  name                     = local.front_door_origin_group_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
  session_affinity_enabled = true

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/status-0123456789abcdef"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "primary_endpoint_origin" {
  name                          = local.front_door_origin_name
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group.id

  enabled                        = true
  host_name                      = replace(azurerm_api_management.api.gateway_regional_url, "https://", "")
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = replace(azurerm_api_management.api.gateway_regional_url, "https://", "")
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_origin" "secondary_endpoint_origin" {
  name                          = local.front_door_origin_name_2
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group.id

  enabled                        = true
  host_name                      = replace(azurerm_api_management.api.additional_location.0.gateway_regional_url, "https://", "")
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = replace(azurerm_api_management.api.additional_location.0.gateway_regional_url, "https://", "")
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

resource "azurerm_cdn_frontdoor_route" "my_route" {
  name                          = local.front_door_route_name
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.my_endpoint.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.primary_endpoint_origin.id]

  supported_protocols    = ["Http", "Https"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpsOnly"
  link_to_default_domain = true
  https_redirect_enabled = true
}

# The below will allow us a way to build a rules engine to test specific sets.
resource "azurerm_cdn_frontdoor_rule_set" "apim_specifier" {
  name                     = "SpecifyAPIMInstance"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
}

resource "azurerm_cdn_frontdoor_origin_group" "my_origin_group_primary_only" {
  name                     = "${local.front_door_origin_group_name}-primary-only"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
  session_affinity_enabled = true

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/status-0123456789abcdef"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "primary_endpoint_origin2" {
  name                          = "${local.front_door_origin_name}-primary-only"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group_primary_only.id

  enabled                        = true
  host_name                      = replace(azurerm_api_management.api.gateway_regional_url, "https://", "")
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = replace(azurerm_api_management.api.gateway_regional_url, "https://", "")
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

# The below will allow us a way to build a rules engine to test specific sets.
resource "azurerm_cdn_frontdoor_origin_group" "my_origin_group_secondary_only" {
  name                     = "${local.front_door_origin_group_name}-secondary-only"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.my_front_door.id
  session_affinity_enabled = true

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/status-0123456789abcdef"
    request_type        = "HEAD"
    protocol            = "Https"
    interval_in_seconds = 100
  }
}

resource "azurerm_cdn_frontdoor_origin" "secondary_endpoint_origin2" {
  name                          = "${local.front_door_origin_name}-secondary-only"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group_secondary_only.id

  enabled                        = true
  host_name                      = replace(azurerm_api_management.api.additional_location.0.gateway_regional_url, "https://", "")
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = replace(azurerm_api_management.api.additional_location.0.gateway_regional_url, "https://", "")
  priority                       = 1
  weight                         = 1000
  certificate_name_check_enabled = true
}

# add a test rule to the rules engine (ruleset above)
resource "azurerm_cdn_frontdoor_rule" "central" {
  depends_on = [ azurerm_cdn_frontdoor_rule_set.apim_specifier ]

  name                     = "RouteToCentral"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.apim_specifier.id
  order                 = 1
  behavior_on_match = "Stop"

  conditions {
    request_header_condition {
      header_name      = "x-apim-instance"
      operator         = "Equal"
      negate_condition = false
      match_values     = ["Central"]
      transforms = []
    }
  }

  actions {
    route_configuration_override_action {
      cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group_secondary_only.id
      forwarding_protocol           = "HttpsOnly"
      cache_behavior                = "Disabled"
    }
  }
}

resource "azurerm_cdn_frontdoor_rule" "east" {
  depends_on = [ azurerm_cdn_frontdoor_rule_set.apim_specifier ]

  name                     = "RouteToEast"
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.apim_specifier.id
  order                 = 2
  behavior_on_match = "Stop"

  conditions {
    request_header_condition {
      header_name      = "x-apim-instance"
      operator         = "Equal"
      negate_condition = false
      match_values     = ["East"]
      transforms = []
    }
  }

  actions {
    route_configuration_override_action {
      cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.my_origin_group_primary_only.id
      forwarding_protocol           = "HttpsOnly"
      cache_behavior                = "Disabled"
    }
  }
}
  
  