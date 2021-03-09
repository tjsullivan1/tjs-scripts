Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

sleep 10

choco install python
choco install powershell-core
choco install nodejs
choco install microsoft-windows-terminal
choco install git.install
choco install gh
choco install postman
choco install azure-cli
choco install az.powershell
choco install azure-functions-core-tools-3
choco install bicep
choco install gnucash
choco install pycharm
choco install vscode
choco install microsoft-edge-insider-dev