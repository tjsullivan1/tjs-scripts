param automation_account_name string 
param location string = resourceGroup().location
param start_time string = utcNow(+1d)

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
  location: location
  properties: {
    runbookType: 'PowerShell'
    publishContentLink: {
        uri: 'https://raw.githubusercontent.com/tjsullivan1/tjs-scripts/master/PowerShell/Remove-ExpiredResources.ps1'
    }
  }
}

resource myaa_DailySchedule 'Microsoft.Automation/automationAccounts/schedules@2020-01-13-preview' = {
  parent: myaa
  name: 'DailySchedule'
  properties: {
    startTime: start_time
    expiryTime: '9999-12-31T17:59:00-06:00'
    interval: 1
    frequency: 'Day'
    timeZone: 'America/Chicago'
  }
}

resource myaa_jobSchedule_cleanup 'Microsoft.Automation/automationAccounts/jobSchedules@2022-08-08' = {
  name: '${automation_account_name}/Remove-ExpireResourcesSchedule'
  properties: {
    runbook: {
      name: myaa_cleanup_runbook.name
    }
    schedule: {
      name: myaa_DailySchedule.name
    }
  }
}
