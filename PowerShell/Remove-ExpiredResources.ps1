[cmdletbinding()]
param(
)

$Conn = Get-AutomationConnection -Name AzureRunAsConnection
$connection = Connect-AzAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
Set-AzContext -Subscription $subscriptionId

$rgs = Get-AzResourceGroup | Select -Property ResourceGroupName, @{n="ExpirationDate";e={$_.Tags.ExpirationDate}} | where ExpirationDate -NotLike ""

write-output "Here are the expired RGs:"
write-output $rgs
write-output "`n"

foreach ($rg in $rgs) {
    try {
        $rg_name = $rg.ResourceGroupName
        Write-Output "Preparing to work through $rg_name"
        $expDate = [datetime]::parseexact($rg.ExpirationDate,'O',$null)
        write-output "$rg_name will expire on $expDate"

        if ((Get-Date) -gt $expDate) {
            write-output "Checking to see if $rg_name has a longLived tag" # I would also highly recommend resource locks on critical infra :)
			if ($rg_name.StartsWith('MC')) {
				write-output "$rg_name is a Kubernetes managed resource group"
			} else {
				if (!(Get-AzResourceGroup -name $rg_name | select @{n="LongLived";e={$_.Tags.longLived}} | select -ExpandProperty LongLived)) {
					write-output "$rg_name is expired, deleting..."
					Remove-AzResourceGroup -Name $rg_name -Force
					Write-Output "Deleted resource group $rg_name"
				} else {
					write-output "$rg_name is set to be longLived"
				}
			}
        } else {
            write-output "$rg_name is not expired"
        }
    } catch {
        write-output "had an issue with $rg"
    }
    write-output "`n"
}
