module "east" {
  source = "./module/"

  resource_group_location = "eastus"
  indicator_suffix        = "1"
  ingress_ip              = "20.81.61.165"
  ingress_name            = "east-ingress"
  secondary_ingress_name  = "west-ingress"
  custom_subdomain_names  = ["customer1", "customer2"]
  domain_name             = "sullivantim.com"
  zone_resource_group     = "rg-dns"

}

module "west" {
  source = "./module/"

  resource_group_location = "westus"
  indicator_suffix        = "2"
  ingress_ip              = "104.42.36.130"
  ingress_name            = "west-ingress"
  secondary_ingress_name  = "east-ingress"
  custom_subdomain_names  = ["customer3", "customer4"]
  domain_name             = "sullivantim.com"
  zone_resource_group     = "rg-dns"

}