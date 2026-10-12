variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "private_endpoint_subnet_id" { type = string }
variable "web_vnet_id" { type = string }
variable "app_vnet_id" { type = string }
variable "sql_vnet_id" { type = string }
variable "hub_vnet_id" { type = string }
variable "sql_admin_username" { type = string }
variable "sql_admin_password" { type = string; sensitive = true }
variable "tags" { type = map(string); default = {} }
