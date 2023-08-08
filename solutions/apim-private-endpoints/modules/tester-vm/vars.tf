variable "name" {
 type = string 
}

variable "resource_group" {
 type = string 
}

variable "location" {
 type = string 
}

variable "subnet_id" {
 type = string 
}
  
variable "ssh_key_path" {
 type = string 
 default = "~/.ssh/id_rsa.pub"
}