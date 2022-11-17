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


// Define the modules for the AA
resource module_Az_Accounts 'Microsoft.Automation/automationAccounts/modules@2020-01-13-preview' = {
  parent: myaa
  name: 'Az'
  properties: {
    contentLink: {
      uri: 'https://www.powershellgallery.com/packages/Az/9.1.1'
    }
  }
}
