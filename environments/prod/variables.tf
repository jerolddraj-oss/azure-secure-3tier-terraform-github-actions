variable "subscription_id" { type = string; description = "Azure subscription ID." }
variable "location" { type = string; default = "East US"; description = "Azure region." }
variable "name_prefix" {
  type    = string
  default = "secure3tier"
  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.name_prefix))
    error_message = "Use 3-12 lowercase letters and digits."
  }
}
variable "tags" { type = map(string); default = {} }
variable "hub_address_space" { type = string; default = "10.0.0.0/16" }
variable "firewall_subnet_cidr" { type = string; default = "10.0.0.0/26" }
variable "appgw_subnet_cidr" { type = string; default = "10.0.1.0/24" }
variable "web_address_space" { type = string; default = "10.1.0.0/16" }
variable "web_subnet_cidr" { type = string; default = "10.1.1.0/24" }
variable "app_address_space" { type = string; default = "10.2.0.0/16" }
variable "app_subnet_cidr" { type = string; default = "10.2.1.0/24" }
variable "sql_address_space" { type = string; default = "10.3.0.0/16" }
variable "sql_subnet_cidr" { type = string; default = "10.3.1.0/24" }
variable "web_private_ip" { type = string; default = "10.1.1.4" }
variable "app_private_ip" { type = string; default = "10.2.1.4" }
variable "admin_username" { type = string; default = "azureadmin" }
variable "ssh_public_key" { type = string; sensitive = true }
variable "sql_admin_username" { type = string; default = "sqlbootstrapadmin" }
variable "sql_admin_password" { type = string; sensitive = true }
variable "tls_certificate_pfx_base64" { type = string; sensitive = true }
variable "tls_certificate_password" { type = string; sensitive = true }
