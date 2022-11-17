param automation_account_name string 
param location string = resourceGroup().location

resource myaa 'Microsoft.Automation/automationAccounts@2022-08-08' = {
  name: automation_account_name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties:{
    sku: {
      name: 'Basic'
    }
  }
}
