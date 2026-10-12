variable "name_prefix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "firewall_subnet_id" { type = string }
variable "web_cidr" { type = string }
variable "web_subnet_cidr" { type = string }
variable "app_cidr" { type = string }
variable "app_subnet_cidr" { type = string }
variable "sql_cidr" { type = string }
variable "sql_subnet_cidr" { type = string }
variable "tags" { type = map(string); default = {} }
