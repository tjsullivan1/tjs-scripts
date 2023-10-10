terraform init
terraform apply --auto-approve

# Get the output from kubernetes for cluster 1 and run it
az aks get-credentials

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz

k apply -f aks-mt-afd-east.yaml

k get ingress

# Repeat the process with second AKS cluster & region

az aks get-credentials

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz

k apply -f aks-mt-afd-west.yaml

# Edit the ingress IPs in terraform

terraform apply --auto-approve
