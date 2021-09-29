param vmName string
param location string

resource vmName_AzureMonitorWindowsAgent 'Microsoft.Compute/virtualMachines/extensions@2020-06-01' = {
  name: '${vmName}/AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
  }
}