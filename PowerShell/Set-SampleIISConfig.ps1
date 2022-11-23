Install-WindowsFeature -name Web-Server -IncludeManagementTools


$filePath = 'C:\inetpub\wwwroot\iisstart.htm'
$tempFilePath = "$env:TEMP\$($filePath | Split-Path -Leaf)"
$hostname = hostname
$find = '<body>'
$replace = "<body><h1>$hostname</h1>"

(Get-Content -Path $filePath) -replace $find, $replace | Add-Content -Path $tempFilePath

Copy-Item -Path $tempFilePath -Destination $filePath -Force

# This is needed for the loopback adapter module to install
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

# From https://github.com/MicrosoftDocs/azure-docs/issues/67288
# name for the loopback adapter interface that will be created.
$loopback_name = 'Loopback'

# The name for the servers main network interface. This will be updated to allow weak host send/receive which is most likely required for the traffic to work for the loopback interface.
$primary_interface = 'Ethernet'

# The IPv4 address that you would like to assign to the loopback interface along with the prefix length (eg. if the IP is routed to the server usually you would set the prefix length to 32).
$loopback_ipv4 = '10.3.2.6'
$loopback_ipv4_length = '32'

Install-Module -Name LoopbackAdapter -MinimumVersion 1.2.0.0 -Force
Import-Module -Name LoopbackAdapter

New-LoopbackAdapter -Name $loopback_name -Force

$interface_loopback = Get-NetAdapter -Name $loopback_name
$interface_main = Get-NetAdapter -Name $primary_interface

Set-NetIPInterface -InterfaceIndex $interface_loopback.ifIndex -InterfaceMetric "254" -WeakHostReceive Enabled -WeakHostSend Enabled -DHCP Disabled
Set-NetIPInterface -InterfaceIndex $interface_main.ifIndex -WeakHostReceive Enabled

New-NetIPAddress -InterfaceAlias $loopback_name -IPAddress $loopback_ipv4 -PrefixLength $loopback_ipv4_length -AddressFamily ipv4
