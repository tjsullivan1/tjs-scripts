
# Cross Tenant Service Principal Password Resets

This solution is intended to demonstrate how a organization who needs to provide a service principal to their partner/customer can facilitate an automated password rotation process.

## Deployment

Currently, there is no template for deployment. Here are the resources required:
- Two Entra ID Tenants - one representing organization A (provider) and oen representing organization B (customer)
- Customer should have a Key Vault with Azure RBAC enabled instead of access plicies
- Each organization should have an Azure subscription

### Org A Steps
#### Initial Service Principal
- Create a service principal and give it reader access to an Azure subscription
```az ad sp create-for-rbac --name 'organization-a-sp-maker-for-org-b' --role Reader --scopes /subscriptions/```

- This will output an appID and password for you to use later. 
- Assign the new App permissions to Application.ReadWrite.OwnedBy
- Grant admin consent

#### Create Second Service Principal

- Login as the first service principal
- Create the next service principal
```az ad sp create-for-rbac --name 'organization-a-user-for-b' --skip-assignment```

### Org B Steps
#### Create Enterprise Application
- Organization A should provide the App ID for the first service principal, this will be the input for Organization B's enterprise app:
```new-azureadserviceprincipal -appid <app_id_of_spone>```

#### Give SP Permissions to Key Vault

```New-AzRoleAssignment -objectid <object-id-from-previous-step> -scope <customer-key-vault-id> -RoleDefinitionName 'Key Vault Secrets Officer' ```
## Demo

- As Org A, login with your first service principal, specifying your own tenant:
```az login --service-principal -u <sp-1-id> -p <sp-1-pwd> -t <org1-tenant-id>```
- Reset the password for the second service principal, saving the password to a variable:
```$pw = az ad sp credential reset --id <SP-2-id> --query 'password' -o tsv```
- Login as the first service principal, but to the org b tenant:
```az login --service-principal -u <sp-1-id> -p <sp-1-pwd> -t <org2-tenant-id>```
- Now you can set the secret value to the password you generated:
```az keyvault secret set --name orgb-pw-in-orga --value $pw  --vault-name <orgb-keyvault-name>```

## License

[MIT](https://choosealicense.com/licenses/mit/)


## Tech Stack

- Azure Resource Manager / Azure CLI
- Azure Key Vault
- PowerShell
- Graph API
## Authors

- [@tjsullivan1](https://www.github.com/tjsullivan1)


## Contributing

Contributions are always welcome!

See `contributing.md` for ways to get started.

Please adhere to this project's `code of conduct`.


## Roadmap

- Polish to use all powershell or all cli cmds