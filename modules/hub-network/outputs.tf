output "vnet_id" { value = azurerm_virtual_network.this.id }
output "vnet_name" { value = azurerm_virtual_network.this.name }
output "firewall_subnet_id" { value = azurerm_subnet.firewall.id }
output "appgw_subnet_id" { value = azurerm_subnet.app_gateway.id }
