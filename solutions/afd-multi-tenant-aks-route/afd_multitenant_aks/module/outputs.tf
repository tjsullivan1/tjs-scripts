# outputs.tf

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.cluster1.kube_config.0.client_certificate
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.cluster1.kube_config_raw
  sensitive = true
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.cluster1.name
}

output "resource_group_name" {
  value = azurerm_kubernetes_cluster.cluster1.resource_group_name
}

output "connection_string" {
  value = "az aks get-credentials --resource-group ${azurerm_kubernetes_cluster.cluster1.resource_group_name} --name ${resource.azurerm_kubernetes_cluster.cluster1.name}"
}