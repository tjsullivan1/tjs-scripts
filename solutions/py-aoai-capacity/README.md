
# Terraform Check Azure Open AI Capacity

This solution sample demonstrates how you can use Terraform to call a Python script. In this sample, the python script calls an Azure OpenAI capacity endpoint, finds the matching model, and makes it a terraform value.


## License

[MIT](https://choosealicense.com/licenses/mit/)


## Deployment

To use this project, you will need to install the python requirements

```bash
  pip install -r requirements.txt
```

You then have the choice of modifying the terraform to include all of the parameters, or create a .env file with ACCESS_TOKEN, SUBSCRIPTION_ID, or LOCATION as desired to use defaults. In the sample tf code here, the only value we need to add to our ENV variables is ACCESS_TOKEN. 

Then, when we execute the terraform code, we will get an output that looks like this:
```bash

terraform apply --auto-approve
data.azurerm_subscription.current: Reading...
data.azurerm_subscription.current: Read complete after 0s [id=/subscriptions/<sub>]
data.external.test: Reading...
data.external.test: Read complete after 0s [id=-]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration and found no differences, so no changes are needed.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

remaining_capacity = "120"
test = tomap({
  "model_name" = "OpenAI.Standard.text-davinci-003"
  "remaining" = "120"
})
```

This isn't super useful in itself, but then you can add a try to your terraform resource definition to ensure you have a fallback capacity amount:

```bash

esource "azurerm_cognitive_deployment" "example" {
  name                 = "example-cd"
  cognitive_account_id = azurerm_cognitive_account.example.id
  model {
    format  = "OpenAI"
    name    = "text-curie-001"
    version = "1"
  }

  scale {
    type = "Standard"
    capacity = try(var.desired_capacity, local.capacity.remaining)
  }
}

```


## Tech Stack


## Authors

- [@tjsullivan1](https://www.github.com/tjsullivan1)


## Contributing

Contributions are always welcome!

See `contributing.md` for ways to get started.

Please adhere to this project's `code of conduct`.


## Roadmap


## Acknowledgements

Special thanks to my colleagues for reviewing this and giving me the push to share with a broader community :)

 - [Mike Sweany](https://www.linkedin.com/in/mikesweany/)