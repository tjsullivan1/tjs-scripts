<#       
Copyright (c) Tim Sullivan. All rights reserved.
Licensed under the MIT license. See LICENSE file in the project root for full license information.
#>

Get-AzResourceGroup | % { 
    $rg_name = $_.ResourceGroupName
    Get-AzUserAssignedIdentity -ResourceGroupName $rg_name
}


#TODO: Add queries for Azure Functions
#TODO: Add queries for Azure Logic Apps
#TODO: Add queries for Azure Service Bus
#TODO: Add queries for Azure Event Hubs
#TODO: Add queries for Azure API Management
#TODO: Add queries for Azure Container Instances

get-azvm | % { 
    $man_id = $_.identity.principalid
    $name = $_.Name
    $type = $_.type
    $rg = $_.ResourceGroupName
    
    $obj = [PSCustomObject]@{
        ResourceName = $name
        ResourceGroup = $rg
        ResourceType = $type
        ManagedServiceID = $man_id
    } 

    write-output $obj
}

get-azwebapp | % { 
    $man_id = $_.identity.principalid
    $name = $_.Name
    $type = $_.type
    $rg = $_.ResourceGroup
    
    $obj = [PSCustomObject]@{
        ResourceName = $name
        ResourceGroup = $rg
        ResourceType = $type
        ManagedServiceID = $man_id
    } 

    write-output $obj
}