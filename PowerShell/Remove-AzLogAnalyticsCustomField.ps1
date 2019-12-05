<#
.SYNOPSIS
This cmdlet will help to remove custom fields from a log analytics workspace. This can be useful if you start to hit limits.

.PARAMETER token
An Azure Bearer token. To get this, run `az account get-access-token | jq '.accessToken'` from the Azure Cloud Shell (bash).

.PARAMETER customField
The name of the custom field. To get a list of all the fields, run the following query in Log Analytics:
    AzureDiagnostics
    | project data = pack_all(), ResourceProvider 
    | mvexpand data limit 550
    | parse tostring(data) with '{"' key : string '":' value : string '}'
    | distinct key

.PARAMETER workspace
The workspace resourceID. To get this, run `(Get-AzOperationalInsightsWorkspace -Name $name -ResourceGroupName $rg).ResourceId` where $name is the name for your workspace and $rg is the resource group containing that workspace.
It should look something like this: /subscriptions/$subscriptionId/resourcegroups/$rgName/providers/microsoft.operationalinsights/workspaces/$workspaceName

.EXAMPLE

.\Remove-AzLogAnalyticsCustomField.ps1 -token $token -customField 'BackupItemUniqueId_s' -workspace $workspace

.NOTES

Copyright (c) Tim Sullivan. All rights reserved.
Licensed under the MIT license. See LICENSE file in the project root for full license information.

#>
#Requires -Version 6.0
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $token,

    [Parameter(Mandatory=$true)]
    [string]
    $customField,

    [Parameter(Mandatory=$true)]
    [string]
    $workspace
)

$headers = @{
    'X-HTTP-Method' = 'DELETE'
    'x-ms-client-auth-token' = "Bearer $token"
}

$body = @{
    "workspacePath" = "$workspace"
    "data" = "null"
}

$stoken = ConvertTo-SecureString $token -Force -AsPlainText

$uri = "https://www.mms.microsoft.com/Embedded/Api/arm/search/customFields?name=" + $customField + "&sourceType=AzureDiagnostics"

Write-Verbose $uri

Invoke-RestMethod -Method POST -Authentication Bearer -Token $stoken -Uri $uri -Headers $headers -Body (ConvertTo-Json $body) -ContentType 'application/json' -SkipHeaderValidation