#!/bin/bash

# Show the /dev/disk directory
ls /dev/disk

# Update CentOS 7
sudo yum -y update

# Import MSFT Repo Key
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

# Add the azure-cli repo
echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/azure-cli.repo

# Install az cli
sudo dnf install azure-cli
