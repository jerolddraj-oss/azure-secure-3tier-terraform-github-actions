resource "azurerm_public_ip" "this" {
  name = "${var.name_prefix}-appgw-pip"
  location = var.location
  resource_group_name = var.resource_group_name
  allocation_method = "Static"
  sku = "Standard"
  zones = ["1", "2", "3"]
  tags = var.tags
}
resource "azurerm_web_application_firewall_policy" "this" {
  name = "${var.name_prefix}-waf-policy"
  location = var.location
  resource_group_name = var.resource_group_name
  policy_settings {
    enabled = true
    mode = "Prevention"
  }
  managed_rules {
    managed_rule_set {
      type = "OWASP"
      version = "3.2"
    }
  }
  tags = var.tags
}
resource "azurerm_application_gateway" "this" {
  name = "${var.name_prefix}-appgw-waf"
  location = var.location
  resource_group_name = var.resource_group_name
  zones = ["1", "2", "3"]
  enable_http2 = true
  firewall_policy_id = azurerm_web_application_firewall_policy.this.id
  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
    capacity = 2
  }
  gateway_ip_configuration {
    name = "gateway-ip-config"
    subnet_id = var.appgw_subnet_id
  }
  frontend_ip_configuration {
    name = "public-frontend"
    public_ip_address_id = azurerm_public_ip.this.id
  }
  frontend_port { name = "https"; port = 443 }
  ssl_certificate {
    name = "listener-pfx"
    data = var.tls_certificate_pfx_base64
    password = var.tls_certificate_password
  }
  http_listener {
    name = "https-listener"
    frontend_ip_configuration_name = "public-frontend"
    frontend_port_name = "https"
    protocol = "Https"
    ssl_certificate_name = "listener-pfx"
  }
  backend_address_pool {
    name = "web-backend"
    ip_addresses = [var.web_backend_ip]
  }
  backend_http_settings {
    name = "web-http"
    cookie_based_affinity = "Disabled"
    port = 80
    protocol = "Http"
    request_timeout = 30
    probe_name = "web-health"
  }
  probe {
    name = "web-health"
    protocol = "Http"
    path = "/"
    host = "127.0.0.1"
    interval = 30
    timeout = 30
    unhealthy_threshold = 3
    match { status_code = ["200-399"] }
  }
  request_routing_rule {
    name = "https-to-web"
    rule_type = "Basic"
    http_listener_name = "https-listener"
    backend_address_pool_name = "web-backend"
    backend_http_settings_name = "web-http"
    priority = 100
  }
  tags = var.tags
}
