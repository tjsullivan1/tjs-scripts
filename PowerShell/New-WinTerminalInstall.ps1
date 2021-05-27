param (
    $Version = "v1.7.1091.0",
    $BundleName = "Microsoft.WindowsTerminal_1.7.1091.0_8wekyb3d8bbwe.msixbundle"
)

$url = "https://github.com/microsoft/terminal/releases/download/$Version/$BundleName" 

write-host "Downloading $url"

invoke-webrequest $url -outfile $BundleName

write-host "Importing Appx Module"

Import-Module Appx -UseWindowsPowerShell

write-host "Installing $BundleName"

Add-AppxPackage $BundleName

write-host "Installed $BundleName"