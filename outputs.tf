output "resource_group_name" {
  value       = azurerm_resource_group.main.name
  description = "Resource group containing the baseline infrastructure."
}
output "application_gateway_public_ip" {
  value       = azurerm_public_ip.appgw.ip_address
  description = "Public IPv4 address for the WAF entry point."
}
output "web_vm_private_ip" {
  value       = azurerm_network_interface.web.private_ip_address
  description = "Private IP of the demo web VM."
}
output "app_vm_private_ip" {
  value       = azurerm_network_interface.app.private_ip_address
  description = "Private IP of the demo app VM."
}
output "sql_server_fqdn" {
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
  description = "SQL server FQDN; private DNS should resolve it to the private endpoint from linked VNets."
}
output "firewall_private_ip" {
  value       = azurerm_firewall.main.ip_configuration[0].private_ip_address
  description = "Private IP used as the UDR next hop."
}
