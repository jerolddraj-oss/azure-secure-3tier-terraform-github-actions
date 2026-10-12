variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "hub_address_space" { type = string }
variable "firewall_subnet_cidr" { type = string }
variable "appgw_subnet_cidr" { type = string }
variable "tags" { type = map(string); default = {} }
