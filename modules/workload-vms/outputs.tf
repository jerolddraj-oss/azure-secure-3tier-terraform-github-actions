output "web_private_ip" { value = azurerm_network_interface.web.private_ip_address }
output "app_private_ip" { value = azurerm_network_interface.app.private_ip_address }
