
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

