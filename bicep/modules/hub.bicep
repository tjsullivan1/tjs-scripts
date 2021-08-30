param hubNetwork object
param azureFirewall object
param bastionHost object
param vpnGateway object
param logAnalyticsWorkspaceId string
param location string

resource vnetHub 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: hubNetwork.name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubNetwork.addressPrefix
      ]
    }
    subnets: [
      {
        name: azureFirewall.subnetName
        properties: {
          addressPrefix: azureFirewall.subnetPrefix
        }
      }
      {
        name: bastionHost.subnetName
        properties: {
          addressPrefix: bastionHost.subnetPrefix
        }
      }
      {
        name: vpnGateway.subnetName
        properties: {
          addressPrefix: vpnGateway.subnetPrefix
        }
      }
    ]
  }
}

resource diagVnetHub 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'diagVnetHub'
  scope: vnetHub
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

resource pipFirewall 'Microsoft.Network/publicIPAddresses@2019-11-01' = {
  name: azureFirewall.publicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2020-05-01' = {
  name: azureFirewall.name
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: azureFirewall.name
        properties: {
          publicIPAddress: {
            id: pipFirewall.id
          }
          subnet: {
            id: '${vnetHub.id}/subnets/${azureFirewall.subnetName}'
          }
        }
      }
    ]
  }
}

resource diagFirewall 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = {
  name: 'diagFirewall'
  scope: firewall
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
      {
        category: 'AzureFirewallDnsProxy'
        enabled: true
      }
    ]
  }
}

resource azureFirewallRoutes 'Microsoft.Network/routeTables@2020-05-01' = {
  name: azureFirewall.routeName
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: azureFirewall.routeName
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: reference(firewall.id, '2020-05-01').ipConfigurations[0].properties.privateIpAddress
        }
      }
    ]
  }
}

output vnetHubId string = vnetHub.id
output routeTableId string = azureFirewallRoutes.id
