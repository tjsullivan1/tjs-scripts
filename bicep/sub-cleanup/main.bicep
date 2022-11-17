targetScope = 'subscription'

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
      daysToAdd: {
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
            field: '[concat("tags[", parameters("tagName"), "]")]'
            notEquals: 'DefaultResourceGroup-EUS'
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
              path: 'tags[parameters("tagName")]'
              value: 'formatDateTime(addDays(now(), parameters("daysToAdd")), "yyyy-MM-dd")'
            }
          ]
        }
      }
    }
  }  
}
