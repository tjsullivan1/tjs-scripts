Install-WindowsFeature -name Web-Server -IncludeManagementTools


$filePath = 'C:\inetpub\wwwroot\iisstart.htm'
$tempFilePath = "$env:TEMP\$($filePath | Split-Path -Leaf)"
$hostname = hostname
$find = '<body>'
$replace = "<body><h1>$hostname</h1>"

(Get-Content -Path $filePath) -replace $find, $replace | Add-Content -Path $tempFilePath

Copy-Item -Path $tempFilePath -Destination $filePath -Force
