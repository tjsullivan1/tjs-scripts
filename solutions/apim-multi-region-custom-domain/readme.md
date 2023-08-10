# Azure APIM Multi-region with Azure Front Door

This is some terraform to demonstrate APIM in a multi-region fashion fronted by Azure Front Door. This is accomplished with mocking services, but you could replace the inbound policy actions to change the backend that the traffic is being directed to as well. In this sample, Azure Front Door uses the regiona gateway endpoint for East US and the additional gateway in Central US. Based on the gateway region, we respond with a custom mocked response to demonstrate we're in a separate region. Front Door will use its own routing mechanisms by default, but by adding a request header 'x-apim-instance' with a region specified, we will send to that specific endpoint by using the front door rules engine. 

A custom domain could be added to Azure Front Door if desired and that would not impact the routing mechanisms here since we use Azure endpoints for the API Management instance.

## License

[MIT](https://choosealicense.com/licenses/mit/)


## Deployment

- The main.tf file contains everything you need to be successful. 

### Resources Deployed

- A premium Azure API Managment instance in east us with a second gateway in central us.
  - Mocked API responses that change depending on which gateway you hit (just to demonstrate this scenario)
- A standard Azure Front Door, configured to route traffic to the regional APIM endpoints.

## Notes on Deployment

## Tech Stack

- Azure Resource Manager
- Terraform
- Azure API Management
- Azue Front Door

## Authors

- [@tjsullivan1](https://www.github.com/tjsullivan1)


## Contributing

Contributions are always welcome!

See `contributing.md` for ways to get started.

Please adhere to this project's `code of conduct`.


## Roadmap

- Clean up terraform
- Add custom domain suppot

## Acknowledgements