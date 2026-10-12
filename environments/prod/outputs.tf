output "resource_group_name" { value = azurerm_resource_group.main.name }
output "application_gateway_public_ip" { value = module.application_gateway.public_ip_address }
output "web_vm_private_ip" { value = module.workload_vms.web_private_ip }
output "app_vm_private_ip" { value = module.workload_vms.app_private_ip }
output "firewall_private_ip" { value = module.firewall.private_ip_address }
output "sql_server_fqdn" { value = module.sql_private.sql_server_fqdn }
