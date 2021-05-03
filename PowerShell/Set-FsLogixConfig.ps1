# Copied from Azure Repo, customized for SE test environment: https://raw.githubusercontent.com/Azure/azvmimagebuilder/main/solutions/14_Building_Images_WVD/0_installConfFsLogix.ps1
write-host 'AIB Customization: Downloading FsLogix'
New-Item -Path C:\\ -Name fslogix -ItemType Directory -ErrorAction SilentlyContinue
$LocalPath = 'C:\\fslogix'
$WVDflogixURL = 'https://raw.githubusercontent.com/tjsullivan1/tjs-scripts/master/PowerShell/FsLogixSetup.ps1'
$WVDFslogixInstaller = 'FSLogixSetup.ps1'
$outputPath = $LocalPath + '\' + $WVDFslogixInstaller
Invoke-WebRequest -Uri $WVDflogixURL -OutFile $outputPath
write-host "Downloaded script from GithUb"
set-Location $LocalPath

$curr = gci $LocalPath
write-host "$curr"

$fsLogixURL="https://aka.ms/fslogix_download"
$installerFile="fslogix_download.zip"

Invoke-WebRequest $fsLogixURL -OutFile $LocalPath\$installerFile

$curr = gci $LocalPath
write-host "$curr"

Expand-Archive $LocalPath\$installerFile -DestinationPath $LocalPath
write-host 'AIB Customization: Download Fslogix installer finished'

write-host 'AIB Customization: Start Fslogix installer'
.\\FSLogixSetup.ps1 -ProfilePath \\sefslogixprof1.file.core.windows.net\lab\profiles -Verbose 
write-host 'AIB Customization: Finished Fslogix installer' 
