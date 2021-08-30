param hubNetwork object = {
  name: 'vnet-hub-tjs-0827'
  addressPrefix: '10.0.0.0/20'
}

param azureFirewall object = {
  name: 'AzureFirewall'
  publicIPAddressName: 'pip-firewall'
  subnetName: 'AzureFirewallSubnet'
  subnetPrefix: '10.0.3.0/26'
  routeName: 'r-nexthop-to-fw'
}

param bastionHost object = {
  name: 'AzureBastionHost'
  publicIPAddressName: 'pip-bastion'
  subnetName: 'AzureBastionSubnet'
  nsgName: 'nsg-hub-bastion'
  subnetPrefix: '10.0.1.0/29'
}

param vpnGateway object = {
  name: 'vgw-gateway'
  subnetName: 'GatewaySubnet'
  subnetPrefix: '10.0.2.0/27'
  pipName: 'pip-vgw-gateway'
}

param spokeNetwork object = {
  name: 'vnet-spoke-one'
  addressPrefix: '10.100.0.0/16'
  subnetName: 'snet-spoke-resources'
  subnetPrefix: '10.100.0.0/16'
  subnetNsgName: 'nsg-spoke-one-resources'
}

param spokeNetworkTwo object = {
  name: 'vnet-spoke-two'
  addressPrefix: '10.200.0.0/16'
  subnetName: 'snet-spoke-resources'
  subnetPrefix: '10.200.0.0/16'
  subnetNsgName: 'nsg-spoke-two-resources'
}

param imageReference object = {
  publisher: 'Canonical'
  offer: 'UbuntuServer'
  sku: '18.04-LTS'
  version: 'latest'
}

param location string = resourceGroup().location

param adminUserName string = 'tjs'
param vmSize string = 'Standard_B2s'

@secure()
param adminPassword string

var logAnalyticsWorkspaceName = uniqueString(subscription().subscriptionId, resourceGroup().id)

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'Free'
    }
  }
}

module hub '../modules/hub.bicep' = {
  name: 'vnet-hub'
  params: {
    location: location
    vpnGateway: vpnGateway
    azureFirewall: azureFirewall
    hubNetwork: hubNetwork
    bastionHost: bastionHost
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
  }
}

module bastion '../modules/bastion.bicep' = {
  name: 'bst-hub'
  params: {
    bastionHost: bastionHost
    hubId: hub.outputs.vnetHubId
    location: location
  }
}

module spoke1 '../modules/spoke.bicep' = {
  name: 'vnet-spoke1'
  params: {
    bastionHost: bastionHost
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
    spokeNetwork: spokeNetwork
    routeTableId: hub.outputs.routeTableId
  }
}

module spoke2 '../modules/spoke.bicep' = {
  name: 'vnet-spoke2'
  params: {
    bastionHost: bastionHost
    logAnalyticsWorkspaceId: logAnalyticsWorkspace.id
    spokeNetwork: spokeNetworkTwo
    routeTableId: hub.outputs.routeTableId
  }
}

resource peerHubSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-06-01' = {
  name: '${hubNetwork.name}/hub-to-spoke'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke1.outputs.vnetSpokeId
    }
  }
}

resource peerSpokeHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-06-01' = {
  name: '${spokeNetwork.name}/spoke-to-hub'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hub.outputs.vnetHubId
    }
  }
}

resource peerHubSpokeTwo 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-06-01' = {
  name: '${hubNetwork.name}/hub-to-spoke-two'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: spoke2.outputs.vnetSpokeId
    }
  }
}

resource peerSpokeTwoHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-06-01' = {
  name: '${spokeNetworkTwo.name}/spoke-two-to-hub'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: hub.outputs.vnetHubId
    }
  }
}

module vm1 '../modules/simple-vm.bicep' = {
  name: 'vm1'
  params: {
    adminPassword: adminPassword
    adminUsername: adminUserName
    imageReference: imageReference
    location: location
    nicName: 'nic-spoke1-vm1'
    subnetId: spoke1.outputs.spokeSubnetId
    vmName: 'spoke1-vm1'
    vmSize: vmSize
  }
}


module vm2 '../modules/simple-vm.bicep' = {
  name: 'vm2'
  params: {
    adminPassword: adminPassword
    adminUsername: adminUserName
    imageReference: imageReference
    location: location
    nicName: 'nic-spoke2-vm1'
    subnetId: spoke2.outputs.spokeSubnetId
    vmName: 'spoke2-vm1'
    vmSize: vmSize
  }
}

resource testFirewallPolicy 'Microsoft.Network/firewallPolicies@2021-02-01' = {
  name: 'AzureFirewallPolicy'
  location: location
}

resource transitiveRoute 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2020-11-01' = {
  parent: testFirewallPolicy
  name: 'routeBetweenSpokes'
  properties: {
    priority: 100
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        name: 'any-to-any'
        priority: 200
        rules: [
          {
            ruleType: 'NetworkRule'
            ipProtocols: [
              'Any'
            ]
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '*'
            ]
            sourceAddresses: [
              '*'
            ]
            name: 'any-to-any'
          }
        ]
      }
    ]

  }
}
