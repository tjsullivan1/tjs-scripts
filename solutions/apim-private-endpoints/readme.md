# Azure APIM Demonstration with Private Endpoints, Two Scenarios

This is some terraform to demonstrate two different patterns for APIM in a vnet integrated scenario with function backends using Private Endpoints. Scenario 1 is a flat network, all in one virtual network scenario. In my opinion, this is less desirable as you start to scale functionality behind APIM and may not want cross-chatter across backend functions. The second scenario involves two separate virtual networks, one for APIM, one for the function, with separate DNS resolution zones for the API backend.

## License

[MIT](https://choosealicense.com/licenses/mit/)


## Deployment


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
