# Building this scenario

First, you will need to execute the terraform code in the afd_multitenant_aks subdirectory:

```shell
terraform init
terraform apply --auto-approve
```

This will have two ouputs that we'll use in future steps, they'll look like this: 

```shell
cluster1_connection = "az aks get-credentials --resource-group rg-capable-perch-1 --name aks-rg-capable-perch-1"
cluster2_connection = "az aks get-credentials --resource-group rg-splendid-wombat-2 --name aks-rg-splendid-wombat-2"
```

Use that command to connect to the first cluster (we'll call it east in this example). Then, install a basic nginx ingress controller:

```shell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz
```

Once this is successful, build the environment. This will dump everything in the default namespace, so please don' tdo this in production:

```shell
k apply -f aks-mt-afd-east.yaml
```

Once that is completed, wait for an external IP to be added to the ingress controller:

```shell
k get ingress --watch
```

Repeat the process with second AKS cluster & region, using the second terraform output:

```shell
az aks get-credentials

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz

k apply -f aks-mt-afd-west.yaml

k get ingress --watch
```

In the main.tf file, modify the two lines for the ingress controller IPs and redeploy terraform code:

```shell
terraform apply --auto-approve
```
