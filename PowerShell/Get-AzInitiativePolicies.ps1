<#
.SYNOPSIS
This cmdlet will return a list of all of the policy definition IDs and 

.PARAMETER token
An Azure Bearer token. To get this, run `az account get-access-token | jq '.accessToken'` from the Azure Cloud Shell (bash).

.EXAMPLE


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

    $subscription,

    $policySetDefinitionId = '06122b01-688c-42a8-af2e-fa97dd39aa3b'
)

$headers = @{
    'X-HTTP-Method' = 'GET'
    'x-ms-client-auth-token' = "Bearer $token"
}


$stoken = ConvertTo-SecureString $token -Force -AsPlainText

# $uri = "https://www.mms.microsoft.com/Embedded/Api/arm/search/customFields?name=" + $customField + "&sourceType=AzureDiagnostics"
$uri = "https://management.azure.com/subscriptions/" + $subscription + "/providers/Microsoft.Authorization/policySetDefinitions/" + $policySetDefinitionId + "?api-version=2019-09-01"
Write-Verbose $uri

$properties = Invoke-RestMethod -Method GET -Authentication Bearer -Token $stoken -Uri $uri -Headers $headers -ContentType 'application/json' -SkipHeaderValidation

Write-Output $properties
