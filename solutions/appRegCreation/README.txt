
# Application Registration Management Function

This solution leverages Azure Functions, Managed Identity, and the Graph API to provide a simple example of how an organization can manage the creation of app registrations - allowing developers & consumers to create while still ensuring certain information is collected and tracked. 


## Deployment

Currently, there is no template for deployment. Here are the rough steps:

- deploy an Azure Function
- Assign a managed identity to that function
- Assign the managed identity Graph API permissions for Applications.ReadWrite.All, Directory.Read.All, Users.Read.All (see this blog for some info on how this is done: https://gotoguy.blog/2022/03/15/add-graph-application-permissions-to-managed-identity-using-graph-explorer/) 
- Deploy the function code in HttpPSAppreg to your Azure function - be sure to modify line 27 (currently set to my test domain), otherwise UPN lookups will fail


## Demo

Once the function is deployed, you can call the function with Postman. Use a POST to https://<your_function_app_name>.azurewebsites.net/api/HttpPSAppreg, with a JSON body:
```
{
    "Name":"test",
    "Alias":"tim",
    "BusinessUnit":"1234",
}
```

The name is the name that is given to the app registration. In the sample code, we will use this as the suffix to a naming convention that is 'appreg-seconds_since_epoch-name'. The alias is the alias for the user making the request. In production, you would want this to be the authenticated user's value and not a user-inputted value. Finally, business unit is just an example additional tag.

Once the POST happens, Azure AD will generate a new app registration and both the managed identity & user whose alias was passed will be owners. Informational fields will be added to the tags field in the manifest of the app registration. 
## License

[MIT](https://choosealicense.com/licenses/mit/)


## Tech Stack

- Azure Resource Manager
- Azure Functions
- PowerShell
- Graph API
## Authors

- [@tjsullivan1](https://www.github.com/tjsullivan1)


## Contributing

Contributions are always welcome!

See `contributing.md` for ways to get started.

Please adhere to this project's `code of conduct`.


## Roadmap

- Add automation for deployment.