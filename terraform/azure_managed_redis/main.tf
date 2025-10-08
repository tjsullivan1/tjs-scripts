terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "2.7.0"
    }
  }
}
provider "azapi" {}
resource "azapi_resource" "res-0" {
  body = {
    properties = {
      highAvailability  = "Enabled"
      minimumTlsVersion = "1.2"
      publicNetworkAccess = "Enabled"
    }
    sku = {
      name = "Balanced_B0"
    }
  }
  ignore_casing             = false
  ignore_missing_property   = true
  ignore_null_property      = false
  location                  = "canadacentral"
  name                      = "tjsredistest2"
  parent_id                 = "/subscriptions/26101271-a10e-41ab-90ca-b7763d726966/resourceGroups/rg-amr"
  schema_validation_enabled = false
  type                      = "Microsoft.Cache/RedisEnterprise@2025-07-01"
  identity {
    identity_ids = []
    type         = "None"
  }
}

