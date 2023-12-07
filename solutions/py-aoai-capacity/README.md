
# Terraform Check Azure Open AI Capacity

This solution sample demonstrates how you can use Terraform to call a Python script. In this sample, the python script calls an Azure OpenAI capacity endpoint, finds the matching model, and makes it a terraform value.


## License

[MIT](https://choosealicense.com/licenses/mit/)


## Deployment

To use this project, you will need to install the python requirements

```bash
  pip install -r requirements.txt
```

You then have the choice of modifying the terraform to include all of the parameters, or create a .env file with ACCESS_TOKEN, SUBSCRIPTION_ID, or LOCATION as desired to use defaults. 

```bash
az deployment sub create --template-file .\main.bicep -l <yourlocation> -n <deploymentname>
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