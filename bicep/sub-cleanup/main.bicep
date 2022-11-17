targetScope = 'subscription'
param deployment_location string = deployment().location

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
        value: 'ExpirationDate'
      }
      days_to_add: {
        value: 2
      }
    }
  }
}

resource coreRg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-core-it'
  location: deployment_location
  tags: {
    LongLived: 'True'
  }
}

module automationaccount 'aa.bicep' = {
  name: 'aa-tjs-01'
  scope: resourceGroup('rg-core-it')
  params: {
    automation_account_name: 'aa-tjs-01'
    location: deployment_location
  }
}
