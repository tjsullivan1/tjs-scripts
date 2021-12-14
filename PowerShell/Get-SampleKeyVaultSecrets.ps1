if (!(get-module -ListAvailable | where Name -like "Az.KeyVault"))
{
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    set-psrepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module Az.KeyVault
}

Connect-AzAccount -Identity

$pwd = Get-AzKeyVaultSecret -VaultName tjs-kv-1 -Name tim -AsPlainText

$User = "tim@sullivanenterprises.org"
$PWord = ConvertTo-SecureString -String $pwd -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $PWord

Invoke-Command -ComputerName se-dc01 -Credential $credential -ScriptBlock { get-aduser -filter *}