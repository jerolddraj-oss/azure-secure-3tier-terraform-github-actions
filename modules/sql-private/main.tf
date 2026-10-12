resource "random_string" "suffix" { length = 5; upper = false; special = false }
locals { sql_name = substr("${var.name_prefix}-sql-${random_string.suffix.result}", 0, 63) }
resource "azurerm_mssql_server" "this" {
  name = local.sql_name
  resource_group_name = var.resource_group_name
  location = var.location
  version = "12.0"
  administrator_login = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  minimum_tls_version = "1.2"
  public_network_access_enabled = false
  tags = var.tags
}
resource "azurerm_mssql_database" "this" {
  name = "${var.name_prefix}-appdb"
  server_id = azurerm_mssql_server.this.id
  sku_name = "S0"
  max_size_gb = 10
  zone_redundant = false
  tags = var.tags
}
resource "azurerm_private_dns_zone" "this" {
  name = "privatelink.database.windows.net"
  resource_group_name = var.resource_group_name
  tags = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  name = "sql-dns-hub"
  resource_group_name = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id = var.hub_vnet_id
  registration_enabled = false
}
resource "azurerm_private_dns_zone_virtual_network_link" "web" {
  name = "sql-dns-web"
  resource_group_name = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id = var.web_vnet_id
  registration_enabled = false
}
resource "azurerm_private_dns_zone_virtual_network_link" "app" {
  name = "sql-dns-app"
  resource_group_name = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id = var.app_vnet_id
  registration_enabled = false
}
resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name = "sql-dns-sqldb"
  resource_group_name = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  virtual_network_id = var.sql_vnet_id
  registration_enabled = false
}
resource "azurerm_private_endpoint" "this" {
  name = "${var.name_prefix}-sql-pe"
  location = var.location
  resource_group_name = var.resource_group_name
  subnet_id = var.private_endpoint_subnet_id
  private_service_connection {
    name = "sql-private-connection"
    private_connection_resource_id = azurerm_mssql_server.this.id
    subresource_names = ["sqlServer"]
    is_manual_connection = false
  }
  private_dns_zone_group {
    name = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.this.id]
  }
  tags = var.tags
}
