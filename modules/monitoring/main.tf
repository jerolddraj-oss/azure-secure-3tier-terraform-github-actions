resource "azurerm_log_analytics_workspace" "this" {
  name = "${var.name_prefix}-law"
  location = var.location
  resource_group_name = var.resource_group_name
  sku = "PerGB2018"
  retention_in_days = 90
  tags = var.tags
}
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name = "firewall-diagnostics"
  target_resource_id = var.firewall_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  enabled_log { category = "AzureFirewallApplicationRule" }
  enabled_log { category = "AzureFirewallNetworkRule" }
  enabled_log { category = "AzureFirewallDnsProxy" }
  metric { category = "AllMetrics" }
}
