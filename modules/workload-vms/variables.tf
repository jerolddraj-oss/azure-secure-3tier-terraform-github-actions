variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "web_subnet_id" { type = string }
variable "app_subnet_id" { type = string }
variable "web_private_ip" { type = string }
variable "app_private_ip" { type = string }
variable "admin_username" { type = string }
variable "ssh_public_key" { type = string; sensitive = true }
variable "vm_size" { type = string; default = "Standard_B2s" }
variable "tags" { type = map(string); default = {} }
