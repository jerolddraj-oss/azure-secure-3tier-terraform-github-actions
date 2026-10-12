resource "azurerm_network_security_group" "web" {
  name = "${var.name_prefix}-web-nsg"
  location = var.location
  resource_group_name = var.resource_group_name
  tags = var.tags
}
resource "azurerm_network_security_rule" "web_from_waf" {
  name = "Allow-AppGateway-to-Web-80"
  priority = 100
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "80"
  source_address_prefix = "10.0.1.0/24"
  destination_address_prefix = "*"
  resource_group_name = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.web.name
}
resource "azurerm_network_security_rule" "web_deny_vnet" {
  name = "Deny-other-VNet-inbound"
  priority = 200
  direction = "Inbound"
  access = "Deny"
  protocol = "*"
  source_port_range = "*"
  destination_port_range = "*"
  source_address_prefix = "VirtualNetwork"
  destination_address_prefix = "*"
  resource_group_name = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.web.name
}
resource "azurerm_network_security_group" "app" {
  name = "${var.name_prefix}-app-nsg"
  location = var.location
  resource_group_name = var.resource_group_name
  tags = var.tags
}
resource "azurerm_network_security_rule" "app_from_web" {
  name = "Allow-Web-to-App-8080"
  priority = 100
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "8080"
  source_address_prefix = var.web_subnet_cidr
  destination_address_prefix = "*"
  resource_group_name = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.app.name
}
resource "azurerm_network_security_rule" "app_deny_vnet" {
  name = "Deny-other-VNet-inbound"
  priority = 200
  direction = "Inbound"
  access = "Deny"
  protocol = "*"
  source_port_range = "*"
  destination_port_range = "*"
  source_address_prefix = "VirtualNetwork"
  destination_address_prefix = "*"
  resource_group_name = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.app.name
}
resource "azurerm_network_security_group" "sql" {
  name = "${var.name_prefix}-sqldb-nsg"
  location = var.location
  resource_group_name = var.resource_group_name
  tags = var.tags
}
resource "azurerm_network_security_rule" "sql_from_app" {
  name = "Allow-App-to-SQL-1433"
  priority = 100
  direction = "Inbound"
  access = "Allow"
  protocol = "Tcp"
  source_port_range = "*"
  destination_port_range = "1433"
  source_address_prefix = var.app_subnet_cidr
  destination_address_prefix = "*"
  resource_group_name = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.sql.name
}
resource "azurerm_network_security_rule" "sql_deny_web" {
  name = "Deny-Web-to-SQLDB"
  priority = 110
  direction = "Inbound"
  access = "Deny"
  protocol = "*"
  source_port_range = "*"
  destination_port_range = "*"
  source_address_prefix = var.web_address_space
  destination_address_prefix = "*"
  resource_group_name = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.sql.name
}
resource "azurerm_network_security_rule" "sql_deny_other_vnet" {
  name = "Deny-other-VNet-inbound"
  priority = 200
  direction = "Inbound"
  access = "Deny"
  protocol = "*"
  source_port_range = "*"
  destination_port_range = "*"
  source_address_prefix = "VirtualNetwork"
  destination_address_prefix = "*"
  resource_group_name = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.sql.name
}
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id = var.web_subnet_id
  network_security_group_id = azurerm_network_security_group.web.id
}
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id = var.app_subnet_id
  network_security_group_id = azurerm_network_security_group.app.id
}
resource "azurerm_subnet_network_security_group_association" "sql" {
  subnet_id = var.sql_subnet_id
  network_security_group_id = azurerm_network_security_group.sql.id
}
