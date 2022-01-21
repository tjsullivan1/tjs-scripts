param(
    [parameter(Mandatory=$true)]
    [string]$root_domain,
    [parameter(Mandatory=$true)]
    [string]$subdomain,
    [parameter(Mandatory=$true)]
    [string]$keyvault,
    [parameter(Mandatory=$true)]
    [string]$contact_for_certificate,
    [ValidateSet("LE_STAGE","LE_PROD","BUYPASS_PROD","BUYPASS_TEST","ZEROSSL_PROD")]
    [string]$pa_server = "LE_STAGE"
)

# Log in to the current session with our Azure Automation Service Principal
$Conn = Get-AutomationConnection -Name AzureRunAsConnection
Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint

# Build parameter object for the DNS plugin
$token = get-azaccesstoken | select -expand token
$sub_id = Get-AzContext | select -expand subscription | select -ExpandProperty Id

$az_params = @{
  AZSubscriptionId=$sub_id
  AZAccessToken=$token
}

# Request the certificate
Set-PAServer $pa_server

$certificate_name = $subdomain + "." + $root_domain

$cert = New-PACertificate $certificate_name `
    -AcceptTOS -Contact $contact_for_certificate  `
    -DnsPlugin Azure `
    -PluginArgs $az_params `
    -Verbose `
    -force

$chain = $cert.PfxFullChain

$pass = $cert.PfxPass

write-output $chain
write-output $pass

# Key Vault doesn't like periods in the certificate names, so if we specified a subdomain above, we need to replace the periods with a dash.
if ($subdomain -like "*.*") {
    $friendly = $subdomain.replace(".","-")
    Import-AzKeyVaultCertificate -VaultName $keyvault -Name $friendly -FilePath $chain -Password $pass
	$secretname = $friendly + "certificatepassword"
	Set-AzKeyVaultSecret -VaultName $keyvault -Name $secretname -secretvalue $pass 
} else {
    Import-AzKeyVaultCertificate -VaultName $keyvault -Name $subdomain -FilePath $chain -Password $pass
	$secretname = $subdomain + "certificatepassword"
	Set-AzKeyVaultSecret -VaultName $keyvault -Name $secretname -secretvalue $pass 
}
