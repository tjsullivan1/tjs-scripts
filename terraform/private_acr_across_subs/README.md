# Private ACR Across Subs


## License

[MIT](https://choosealicense.com/licenses/mit/)


## Deployment

### Resources Deployed

## Notes on Deployment

Once this was deployed, I enabled the acr login & network access to allow me to push an image to the registry. Re-running the terraform will lock it back down.

Commands:

```
az acr login --name <registry>

docker pull nginx
docker tag nginx <registryname>.azurecr.io/samples/nginx
docker push <registryname>.azurecr.io/samples/nginx

az aks get-credentials --resource-group <rg> --name <aks>

kubectl apply -f acr-nginx.yaml
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