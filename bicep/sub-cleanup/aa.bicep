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

resource myaa_cleanup_runbook 'Microsoft.Automation/automationAccounts/runbooks@2022-08-08' = {
  name: '${automation_account_name}/Remove-ExpireResources'
  properties: {
    runbookType: 'PowerShell'
    publishContentLink: {
        uri: 'https://raw.githubusercontent.com/tjsullivan1/tjs-scripts/master/PowerShell/Remove-ExpiredResources.ps1'
    }
  }
}
