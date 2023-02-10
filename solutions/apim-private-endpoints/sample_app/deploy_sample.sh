#!/bin/bash

# Install the Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install the Azure Functions Core Tools
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg

sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" > /etc/apt/sources.list.d/dotnetdev.list'

sudo apt-get update -y
sudo apt-get install azure-functions-core-tools-4 -y

# Deploy the code to the Azure Functions
func azure functionapp publish func-tjsapi-2wjc-func1
func azure functionapp publish func-tjsapi-2wjc-func2
func azure functionapp publish func-tjsapi-2wjc-func3