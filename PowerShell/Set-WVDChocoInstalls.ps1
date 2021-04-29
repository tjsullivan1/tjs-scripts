choco feature enable -n allowGlobalConfirmation

# language support / runtimes
choco install python
$date = get-date
write-host "$date -- Installed  python"
choco install powershell-core
$date = get-date
write-host "$date -- Installed  powershell-core"
choco install nodejs
$date = get-date
write-host "$date -- Installed  nodejs"
choco install azure-cli
$date = get-date
write-host "$date -- Installed  azure-cli"
choco install az.powershell
$date = get-date
write-host "$date -- Installed  az.powershell"
choco install bicep
$date = get-date
write-host "$date -- Installed  bicep"
choco install terraform
$date = get-date
write-host "$date -- Installed  terraform"

# Dev Tools
choco install git.install
$date = get-date
write-host "$date -- Installed  git.install"
choco install gh
$date = get-date
write-host "$date -- Installed  gh"
choco install postman # This install did not seem to work properly for me.
$date = get-date
write-host "$date -- Installed  postman # This install did not seem to work properly for me."
choco install azure-functions-core-tools-3
$date = get-date
write-host "$date -- Installed  azure-functions-core-tools-3"
choco install pycharm
$date = get-date
write-host "$date -- Installed  pycharm"
choco install vscode
$date = get-date
write-host "$date -- Installed  vscode"

# Various tools
choco install gnucash
$date = get-date
write-host "$date -- Installed  gnucash"
choco install microsoft-windows-terminal # This install did not seem to work properly for me.
$date = get-date
write-host "$date -- Installed  microsoft-windows-terminal # This install did not seem to work properly for me."
choco install microsoft-edge-insider-dev
$date = get-date
write-host "$date -- Installed  microsoft-edge-insider-dev"