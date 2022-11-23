
# Azure ILB Hairpin Solution - Loopback VIP & DSR example

Automation to demonstrate the workaround mentioned here: https://github.com/microsoft/Azure-ILB-hairpin#32-workaround-option-2--loopback-vip--dsr

## License

[MIT](https://choosealicense.com/licenses/mit/)


## Deployment

To deploy this project, you must first clone this repo and login to Azure (requires az cli)

```bash
  az login
```

Ensure you are in the subscription you want to be in `az account show` - if this is wrong, switch contexts with `az account set -s <YOURSUBSCRIPTION>`

Then, from your authenicated command line with the bicep files in your current working directory, execute a subscription deployment. Ensure that your parameters.json contains a good value for at least your administrator account & password (please don't commit your password to source code). You could also add the parameters via command line instead of file if preferred.

```bash
 az deployment group create --resource-group <your-rg>--template-file .\iis-ilb-vms.bicep --parameters @iis-ilb-vms.parameters.json
```

### Resources Deployed

By default, this solution will create:

- an internal load balancer
- three VMs, one with a public IP for RDP, the other two with:
  - IIS customized to display hostname on their default page
  - A loopback adapter with the IP of the ILB configured
- a NAT Gateway to allow the VMs without public IPs to download the script for the custom script extension

## Tech Stack

- Azure Resource Manager
- Azure Load Balancer
- Azure Virtual Machines
- Custom Script Extensions
- PowerShell 5.1
- Azure Bicep

## Authors

- [@tjsullivan1](https://www.github.com/tjsullivan1)


## Contributing

Contributions are always welcome!

See `contributing.md` for ways to get started.

Please adhere to this project's `code of conduct`.


## Roadmap

## Acknowledgements

