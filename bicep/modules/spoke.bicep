param spokeNetwork object
param bastionHost object
param logAnalyticsWorkspaceId string
param routeTableId string
param location string = resourceGroup().location

resource nsgSpoke 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: spokeNetwork.name
  location: location
  properties: {
    securityRules: [
      {
        name: 'bastion-in-vnet'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix:  bastionHost.subnetPrefix
          destinationPortRanges: [
            '22'
            '3389'
          ]
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource diagNsgSpoke 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'diagNsgSpoke'
  scope: nsgSpoke
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
}

resource vnetSpoke 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: spokeNetwork.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeNetwork.addressPrefix
      ]
    }
    subnets: [
      {
        name: spokeNetwork.subnetName
        properties: {
          addressPrefix: spokeNetwork.subnetPrefix
          networkSecurityGroup: {
            id: nsgSpoke.id
          }
          routeTable: {
            id: routeTableId
          }
        }
      }
    ]
  }
}

resource diagVnetSpoke 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'diagVnetSpoke'
  scope: vnetSpoke
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'VMProtectionAlerts'
        enabled: true
      }
    ]
  }
}

output vnetSpokeId string = vnetSpoke.id
output spokeSubnetId string = vnetSpoke.properties.subnets[0].id
