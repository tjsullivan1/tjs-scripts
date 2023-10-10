# outputs.tf

output cluster1_connection {
  value = module.east.connection_string
}

output cluster2_connection {
  value = module.west.connection_string
}