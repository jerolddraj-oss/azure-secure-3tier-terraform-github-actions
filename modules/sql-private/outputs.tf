output "sql_server_fqdn" { value = azurerm_mssql_server.this.fully_qualified_domain_name }
output "private_endpoint_id" { value = azurerm_private_endpoint.this.id }
