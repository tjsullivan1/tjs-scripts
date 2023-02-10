# Azure APIM Demonstration with Private Endpoints, Two Scenarios

This is some terraform to demonstrate two different patterns for APIM in a vnet integrated scenario with function backends using Private Endpoints. Scenario 1 is a flat network, all in one virtual network scenario. In my opinion, this is less desirable as you start to scale functionality behind APIM and may not want cross-chatter across backend functions. The second scenario involves two separate virtual networks, one for APIM, one for the function, with separate DNS resolution zones for the API backend.

## License

[MIT](https://choosealicense.com/licenses/mit/)


## Deployment

Unfortunately, this isn't as fully automated as I would like at this point. Still have some work to do with the function code deploy & the APIM mapping of the function. The APIM mapping is super simple from the portal, and the function deploy is straightforward from CLI, so I'll include the instructions here.

First, deploy your two sets of resources. They are located in the one-vnet/ and two-vnets/ directories (nb. two-vnets actually deploys 3). A terraform init && terraform apply --auto-approve willl deploy the infrastructure. You will then get two sets of infrastructure across several different resource groups to demonstrate the different APIM setups. These deployments (for the vnet integration) will take between 30-60 minutes. Note: APIM is deployed in external mode, but the APIM mode does NOT matter when it comes to its interaction with private link. 

Second, deploy the function code. To do this, modify and run the script "sample_app/deploy_sample.sh" from the tester VM in each deployment (you will need to add an SSH rule to your tester VMs interface or subnet, terraform doesn't do it since you want to restrict to just your IP). 
### Resources Deployed

## Tech Stack

- Azure Resource Manager
- Terraform
- Azure API Management
- Azure Functions
- Azure Virtual Network

## Authors

- [@tjsullivan1](https://www.github.com/tjsullivan1)


## Contributing

Contributions are always welcome!

See `contributing.md` for ways to get started.

Please adhere to this project's `code of conduct`.


## Roadmap

## Acknowledgements
