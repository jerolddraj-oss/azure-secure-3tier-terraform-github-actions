variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "web_subnet_id" { type = string }
variable "app_subnet_id" { type = string }
variable "sql_subnet_id" { type = string }
variable "web_subnet_cidr" { type = string }
variable "web_address_space" { type = string }
variable "app_subnet_cidr" { type = string }
variable "tags" { type = map(string); default = {} }
