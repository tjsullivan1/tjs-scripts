Function Get-AADToken {
    [CmdletBinding()]
    [OutputType([string])]
    PARAM (
        [String]$TenantID,
        [string]$ServicePrincipalId,
        [securestring]$ServicePrincipalPwd
    )
    Try {
        # Set Resource URI to Azure Database
        $resourceAppIdURI = 'https://database.windows.net/'
        Write-Verbose $resourceAppIdURI

        # Set Authority to Azure AD Tenant
        $authority = 'https://login.windows.net/' + $TenantId
        Write-Verbose $authority

        $ClientCred = [Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential]::new($ServicePrincipalId, $ServicePrincipalPwd)
        $authContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]::new($authority)
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $ClientCred)

        $Token = $authResult.Result.AccessToken
    }
    Catch {
        Throw $_
        $ErrorMessage = 'Failed to aquire Azure AD token.'
        Write-Error -Message 'Failed to aquire Azure AD token'
    }
    
    return $Token
}
