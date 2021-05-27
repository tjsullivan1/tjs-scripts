write-host "Started the software installation script using Chocolatey"
choco feature enable -n allowGlobalConfirmation

$date = get-date
write-host "$date -- enabled chocolatey to run with global confirmation.
"
# language support / runtimes
choco install --no-progress python
$date = get-date
write-host "$date -- Installed  python"
choco install --no-progress powershell-core
$date = get-date
write-host "$date -- Installed  powershell-core"
choco install --no-progress nodejs
$date = get-date
write-host "$date -- Installed  nodejs"
choco install --no-progress azure-cli
$date = get-date
write-host "$date -- Installed  azure-cli"
choco install --no-progress az.powershell
$date = get-date
write-host "$date -- Installed  az.powershell"
choco install --no-progress bicep
$date = get-date
write-host "$date -- Installed  bicep"
choco install --no-progress terraform
$date = get-date
write-host "$date -- Installed  terraform"

# Dev Tools
choco install --no-progress git.install
$date = get-date
write-host "$date -- Installed  git.install"
choco install --no-progress gh
$date = get-date
write-host "$date -- Installed  gh"
choco install --no-progress postman # This install did not seem to work properly for me.
$date = get-date
write-host "$date -- Installed  postman # This install did not seem to work properly for me."
choco install --no-progress azure-functions-core-tools-3
$date = get-date
write-host "$date -- Installed  azure-functions-core-tools-3"
choco install --no-progress pycharm
$date = get-date
write-host "$date -- Installed  pycharm"
choco install --no-progress vscode
$date = get-date
write-host "$date -- Installed  vscode"
choco install --no-progress docker-desktop
$date = get-date
write-host "$date -- Installed  docker desktop"

# Install Tooling for Citizen Development
choco install --no-progress netfx-4.6.2-devpack
$date = get-date
write-host "$date -- Installed  installed .net framework dev pack"
choco install --no-progress dotnetcore-3.1-sdk
$date = get-date
write-host "$date -- Installed  installed dot net core sdk"


# Various tools
choco install --no-progress gnucash
$date = get-date
write-host "$date -- Installed  gnucash"
# choco install --no-progress microsoft-windows-terminal # This install did not seem to work properly for me.
# $date = get-date
# write-host "$date -- Installed  microsoft-windows-terminal # This install did not seem to work properly for me."
choco install --no-progress microsoft-edge-insider-dev
$date = get-date
write-host "$date -- Installed  microsoft-edge-insider-dev"