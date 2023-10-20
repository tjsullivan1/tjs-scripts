variable "frontdoor_id" {
    type = string
    description = "The ID for your Front Door instance"
}

variable "ruleset_name" {
    type = string
    description = "The name for the rule set"
}

variable "hostname_map" {
    type = map
    description = "The map of hostnames to match for this rule - should be a max of ten hostnames per rule"
}



resource "azurerm_cdn_frontdoor_rule_set" "ruleset1" {
  cdn_frontdoor_profile_id = var.frontdoor_id
  name                     = var.ruleset_name

}

resource "azurerm_cdn_frontdoor_rule" "rule1" {
  for_each = var.hostname_map
  cdn_frontdoor_rule_set_id = azurerm_cdn_frontdoor_rule_set.ruleset1.id
  name                      = "rule${each.key}"
  order                     = each.key
  actions {
    route_configuration_override_action {
      cache_behavior                = "Disabled"
      cdn_frontdoor_origin_group_id = each.value["origin_group_id"]
      forwarding_protocol           = "HttpOnly"
    }
  }
  conditions {
    host_name_condition {
      match_values = each.value["hostnames"]
      operator     = "BeginsWith"
    }
  }

}

output "ruleset_id" {
    value = azurerm_cdn_frontdoor_rule_set.ruleset1.id
}

