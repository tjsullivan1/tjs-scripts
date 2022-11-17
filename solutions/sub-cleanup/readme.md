
# Automated Cleanup of Sandbox Subscriptions

This solution leverages Azure Automation, Azure Policy, and tags on resource groups to automatically clean up resources based on a schedule.

By default, this will use an ExpirationDate tag on the resource group. With an Azure Policy configured to automatically append the tag to new resource groups with a value two days after the deployment time. It then uses an automation runbook on a schedule to evaluate if the date has passed. If it has, we will remove the resource group (effectively deleting all the resources).

The runbook script will currently ignore groups that have a "LongLived" tag set to True or resource groups starting with "MC*" (MC is the start of the Kubernetes managed cluster RG). The Kubernetes MC group will be cleaned up when the resource group containing the cluster definition is deleted. Resource locks should also be honored by this script (i.e., the script will fail to remove a RG that has a delete lock on it).


## License

[MIT](https://choosealicense.com/licenses/mit/)


## Deployment

To deploy this project, you must first clone this repo and login to Azure (requires az cli)

```bash
  az login
```

Ensure you are in the subscription you want to be in `az account show` - if this is wrong, switch contexts with `az account set -s <YOURSUBSCRIPTION>`

Then, from your authenicated command line with the bicep files in your current working directory, execute a subscription deployment.

```bash
az deployment sub create --template-file .\main.bicep -l <yourlocation> -n <deploymentname>
```

**NB:** If you get a deployment error, try to redeploy. The dependsOn did not always work for me.

### Resources Deployed

This solution will create:

- a custom Azure Policy definition in your subscription called "Add Expiration Date"
- an Azure Policy assignment at the subscription with a system assigned managed identity
- a resource group with a longLived tag
- an automation account
- a PowerShell runbook (from: https://raw.githubusercontent.com/tjsullivan1/tjs-scripts/master/PowerShell/Remove-ExpiredResources.ps1)
- a daily schedule starting one hour from initial deployment
- a job schedule that links the runbook to the schedule

### Possible Customization

You can easily add parameters to tweak:
- the location
- tag name that we look at (though this will NOT update the PowerShell script)
- number of days to increment before Expiration
- resource group name that will contain our automation account
- automation account name




## Tech Stack

- Azure Resource Manager
- Azure Policy
- Azure Automation Accounts
- PowerShell 5.1
- Azure Bicep

## Authors

- [@tjsullivan1](https://www.github.com/tjsullivan1)


## Contributing

Contributions are always welcome!

See `contributing.md` for ways to get started.

Please adhere to this project's `code of conduct`.


## Roadmap

- Add support for additional default resource group types that we want to ignore.
- Add ability to remove resource locks
- Add notifications (so that we don't have to check the Azure automation output)

## Acknowledgements

Special thanks to my colleagues for reviewing this and giving me the push to share with a broader community :)

 - [Matt Lunzer](https://www.linkedin.com/in/mattlunzer/)
 - [Mike Sweany](https://www.linkedin.com/in/mikesweany/)
