<#       
Copyright (c) Tim Sullivan. All rights reserved.
Licensed under the MIT license. See LICENSE file in the project root for full license information.
#>
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