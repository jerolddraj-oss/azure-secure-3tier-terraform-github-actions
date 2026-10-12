resource "azurerm_route_table" "web" {
  name = "${var.name_prefix}-web-rt"
  location = var.location
  resource_group_name = var.resource_group_name
  bgp_route_propagation_enabled = false
  tags = var.tags
}
resource "azurerm_route_table" "app" {
  name = "${var.name_prefix}-app-rt"
  location = var.location
  resource_group_name = var.resource_group_name
  bgp_route_propagation_enabled = false
  tags = var.tags
}
resource "azurerm_route_table" "sql" {
  name = "${var.name_prefix}-sql-rt"
  location = var.location
  resource_group_name = var.resource_group_name
  bgp_route_propagation_enabled = false
  tags = var.tags
}
resource "azurerm_route" "web_default" {
  name = "default-to-firewall"
  resource_group_name = var.resource_group_name
  route_table_name = azurerm_route_table.web.name
  address_prefix = "0.0.0.0/0"
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}
resource "azurerm_route" "app_default" {
  name = "default-to-firewall"
  resource_group_name = var.resource_group_name
  route_table_name = azurerm_route_table.app.name
  address_prefix = "0.0.0.0/0"
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}
resource "azurerm_route" "sql_default" {
  name = "default-to-firewall"
  resource_group_name = var.resource_group_name
  route_table_name = azurerm_route_table.sql.name
  address_prefix = "0.0.0.0/0"
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}
resource "azurerm_route" "web_app" {
  name = "web-to-app-inspection"
  resource_group_name = var.resource_group_name
  route_table_name = azurerm_route_table.web.name
  address_prefix = var.app_cidr
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}
resource "azurerm_route" "web_sql" {
  name = "web-to-sql-inspection"
  resource_group_name = var.resource_group_name
  route_table_name = azurerm_route_table.web.name
  address_prefix = var.sql_cidr
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}
resource "azurerm_route" "app_web" {
  name = "app-to-web-inspection"
  resource_group_name = var.resource_group_name
  route_table_name = azurerm_route_table.app.name
  address_prefix = var.web_cidr
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}
resource "azurerm_route" "app_sql" {
  name = "app-to-sql-inspection"
  resource_group_name = var.resource_group_name
  route_table_name = azurerm_route_table.app.name
  address_prefix = var.sql_cidr
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}
resource "azurerm_route" "sql_web" {
  name = "sql-to-web-inspection"
  resource_group_name = var.resource_group_name
  route_table_name = azurerm_route_table.sql.name
  address_prefix = var.web_cidr
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}
resource "azurerm_route" "sql_app" {
  name = "sql-to-app-inspection"
  resource_group_name = var.resource_group_name
  route_table_name = azurerm_route_table.sql.name
  address_prefix = var.app_cidr
  next_hop_type = "VirtualAppliance"
  next_hop_in_ip_address = var.firewall_private_ip
}
resource "azurerm_subnet_route_table_association" "web" {
  subnet_id = var.web_subnet_id
  route_table_id = azurerm_route_table.web.id
}
resource "azurerm_subnet_route_table_association" "app" {
  subnet_id = var.app_subnet_id
  route_table_id = azurerm_route_table.app.id
}
resource "azurerm_subnet_route_table_association" "sql" {
  subnet_id = var.sql_subnet_id
  route_table_id = azurerm_route_table.sql.id
}
