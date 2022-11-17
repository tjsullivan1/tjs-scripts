targetScope = 'subscription'
param deployment_location string = deployment().location
param tag_name string = 'ExpirationDate'
param days_to_add int = 2
param resource_group_name string = 'rg-core-it'
param automation_account_name string = 'aa-tjs-01'

resource expirationDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'Add Expiration Date'
  scope: subscription()
  properties: {
    description: 'This script will add an expiration date to a resource group.'
    displayName: 'Add Expiration Date to Resource Group'
    mode: 'All'
    parameters: {
      tagName: {
        type: 'String'
        metadata: {
          displayName: 'Tag Name'
          description: 'Name of the tag we plan to use, such as "Date".'
        }
        defaultValue: 'ExpirationDate'
      }
      days_to_add: {
        type: 'Integer'
        metadata: {
          displayName: 'Days to Add'
          description: 'Number of days to add to the current date.'
        }
        defaultValue: 5
      }
    }
    policyType: 'Custom'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Resources/subscriptions/resourceGroups'
          }
          {
            field: '[concat(\'tags[\', parameters(\'tagName\'), \']\')]'
            exists: false
          }
        ]
      }
      then: {
        effect: 'modify'
        details: {
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
          operations: [
            {
              operation: 'add'
              field: '[concat(\'tags[\', parameters(\'tagName\'), \']\')]'
              value:  '[addDays(utcNow(), parameters(\'days_to_add\'))]'
            }
          ]
        }
      }
    }
  }  
}

resource expirationAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'Add Expiration Date'
  scope: subscription()
  location: deployment_location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Add Expiration Date to Resource Group'
    description: 'This script will add an expiration date to a resource group.'
    policyDefinitionId: expirationDefinition.id
    enforcementMode: 'Default'
    parameters: {
      tagName: {
        value: tag_name
      }
      days_to_add: {
        value: days_to_add
      }
    }
  }
}

resource coreRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resource_group_name
  location: deployment_location
  tags: {
    LongLived: 'True'
  }
}

module automationaccount 'aa.bicep' = {
  name: automation_account_name
  scope: resourceGroup(resource_group_name)
  params: {
    automation_account_name: automation_account_name
    location: deployment_location
  }
  dependsOn: [
    coreRg
  ]
}
