terraform {
  required_version = ">= 1.8.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

locals {
  common_tags = merge({
    environment = "production"
    managed_by  = "terraform"
    workload    = "secure-3tier"
  }, var.tags)
}

resource "azurerm_resource_group" "main" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

module "hub_network" {
  source               = "../../modules/hub-network"
  name_prefix          = var.name_prefix
  location             = var.location
  resource_group_name  = azurerm_resource_group.main.name
  hub_address_space    = var.hub_address_space
  firewall_subnet_cidr = var.firewall_subnet_cidr
  appgw_subnet_cidr    = var.appgw_subnet_cidr
  tags                 = local.common_tags
}

module "web_spoke" {
  source              = "../../modules/spoke-network"
  name                = "${var.name_prefix}-web"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.web_address_space
  subnet_name         = "web-subnet"
  subnet_prefix       = var.web_subnet_cidr
  tags                = local.common_tags
}
module "app_spoke" {
  source              = "../../modules/spoke-network"
  name                = "${var.name_prefix}-app"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.app_address_space
  subnet_name         = "app-subnet"
  subnet_prefix       = var.app_subnet_cidr
  tags                = local.common_tags
}
module "sqldb_spoke" {
  source              = "../../modules/spoke-network"
  name                = "${var.name_prefix}-sqldb"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.sql_address_space
  subnet_name         = "private-endpoints"
  subnet_prefix       = var.sql_subnet_cidr
  private_endpoint_network_policies = "Enabled"
  tags                = local.common_tags
}

module "firewall" {
  source              = "../../modules/firewall"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  firewall_subnet_id  = module.hub_network.firewall_subnet_id
  web_cidr            = var.web_address_space
  web_subnet_cidr     = var.web_subnet_cidr
  app_cidr            = var.app_address_space
  app_subnet_cidr     = var.app_subnet_cidr
  sql_cidr            = var.sql_address_space
  sql_subnet_cidr     = var.sql_subnet_cidr
  tags                = local.common_tags
}

module "hub_peering" {
  source              = "../../modules/hub-network/peering"
  resource_group_name = azurerm_resource_group.main.name
  hub_vnet_name       = module.hub_network.vnet_name
  hub_vnet_id         = module.hub_network.vnet_id
  web_vnet_name       = module.web_spoke.vnet_name
  web_vnet_id         = module.web_spoke.vnet_id
  app_vnet_name       = module.app_spoke.vnet_name
  app_vnet_id         = module.app_spoke.vnet_id
  sql_vnet_name       = module.sqldb_spoke.vnet_name
  sql_vnet_id         = module.sqldb_spoke.vnet_id
}

module "spoke_routes" {
  source               = "../../modules/security/routes"
  name_prefix          = var.name_prefix
  location             = var.location
  resource_group_name  = azurerm_resource_group.main.name
  firewall_private_ip  = module.firewall.private_ip_address
  web_subnet_id        = module.web_spoke.subnet_id
  app_subnet_id        = module.app_spoke.subnet_id
  sql_subnet_id        = module.sqldb_spoke.subnet_id
  web_cidr             = var.web_address_space
  app_cidr             = var.app_address_space
  sql_cidr             = var.sql_address_space
  tags                 = local.common_tags
}

module "security" {
  source              = "../../modules/security"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  web_subnet_id       = module.web_spoke.subnet_id
  app_subnet_id       = module.app_spoke.subnet_id
  sql_subnet_id       = module.sqldb_spoke.subnet_id
  web_subnet_cidr     = var.web_subnet_cidr
  web_address_space   = var.web_address_space
  app_subnet_cidr     = var.app_subnet_cidr
  tags                = local.common_tags
}

module "monitoring" {
  source              = "../../modules/monitoring"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  firewall_id         = module.firewall.firewall_id
  tags                = local.common_tags
}

module "workload_vms" {
  source              = "../../modules/workload-vms"
  name_prefix         = var.name_prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  web_subnet_id       = module.web_spoke.subnet_id
  app_subnet_id       = module.app_spoke.subnet_id
  web_private_ip      = var.web_private_ip
  app_private_ip      = var.app_private_ip
  admin_username      = var.admin_username
  ssh_public_key      = var.ssh_public_key
  tags                = local.common_tags
}

module "application_gateway" {
  source                     = "../../modules/application-gateway"
  name_prefix                = var.name_prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  appgw_subnet_id            = module.hub_network.appgw_subnet_id
  web_backend_ip             = module.workload_vms.web_private_ip
  tls_certificate_pfx_base64 = var.tls_certificate_pfx_base64
  tls_certificate_password   = var.tls_certificate_password
  tags                       = local.common_tags
}

module "sql_private" {
  source                     = "../../modules/sql-private"
  name_prefix                = var.name_prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  private_endpoint_subnet_id = module.sqldb_spoke.subnet_id
  web_vnet_id                = module.web_spoke.vnet_id
  app_vnet_id                = module.app_spoke.vnet_id
  sql_vnet_id                = module.sqldb_spoke.vnet_id
  hub_vnet_id                = module.hub_network.vnet_id
  sql_admin_username         = var.sql_admin_username
  sql_admin_password         = var.sql_admin_password
  tags                       = local.common_tags
}
