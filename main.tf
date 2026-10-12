data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

locals {
  suffix = random_string.suffix.result
  names = {
    hub_vnet   = "${var.name_prefix}-hub-vnet"
    web_vnet   = "${var.name_prefix}-web-vnet"
    app_vnet   = "${var.name_prefix}-app-vnet"
    sql_vnet   = "${var.name_prefix}-sqldb-vnet"
    firewall   = "${var.name_prefix}-azfw"
    law        = "${var.name_prefix}-law"
    sql_server = substr(replace("${var.name_prefix}-sql-${local.suffix}", "_", "-"), 0, 63)
  }
  cidrs = {
    hub = "10.0.0.0/16"
    web = "10.1.0.0/16"
    app = "10.2.0.0/16"
    sql = "10.3.0.0/16"
  }
  firewall_private_ip = "10.0.0.4"
  web_vm_ip           = "10.1.1.4"
  app_vm_ip           = "10.2.1.4"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.name_prefix}-rg"
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = local.names.law
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = var.tags
}

# ----------------------------- Hub VNet ---------------------------------------
resource "azurerm_virtual_network" "hub" {
  name                = local.names.hub_vnet
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [local.cidrs.hub]
  tags                = var.tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.0/26"]
}

resource "azurerm_subnet" "app_gateway" {
  name                 = "AppGatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "firewall" {
  name                = "${var.name_prefix}-azfw-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_firewall" "main" {
  name                = local.names.firewall
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.main.id
  zones               = ["1", "2", "3"]
  tags                = var.tags

  ip_configuration {
    name                 = "firewall-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

resource "azurerm_firewall_policy" "main" {
  name                = "${var.name_prefix}-fw-policy"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  threat_intelligence_mode = "Alert"
  dns {
    proxy_enabled = true
  }
  tags = var.tags
}

resource "azurerm_firewall_policy_rule_collection_group" "tiers" {
  name               = "tier-segmentation"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 100

  network_rule_collection {
    name     = "approved-tier-flows"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "Web-to-App-HTTP8080"
      protocols             = ["TCP"]
      source_addresses      = ["10.1.1.0/24"]
      destination_addresses = ["10.2.1.0/24"]
      destination_ports     = ["8080"]
    }

    rule {
      name                  = "App-to-SQL-1433"
      protocols             = ["TCP"]
      source_addresses      = ["10.2.1.0/24"]
      destination_addresses = ["10.3.1.0/24"]
      destination_ports     = ["1433"]
    }
  }

  application_rule_collection {
    name     = "controlled-https-egress"
    priority = 200
    action   = "Allow"

    rule {
      name = "Allow-HTTPS-egress"
      source_addresses = [
        "10.1.0.0/16",
        "10.2.0.0/16",
        "10.3.0.0/16"
      ]
      destination_fqdns = ["*"]
      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

# ----------------------------- Spoke VNets ------------------------------------
resource "azurerm_virtual_network" "web" {
  name                = local.names.web_vnet
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [local.cidrs.web]
  tags                = var.tags
}

resource "azurerm_virtual_network" "app" {
  name                = local.names.app_vnet
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [local.cidrs.app]
  tags                = var.tags
}

resource "azurerm_virtual_network" "sql" {
  name                = local.names.sql_vnet
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [local.cidrs.sql]
  tags                = var.tags
}

resource "azurerm_subnet" "web" {
  name                 = "web-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.web.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_subnet" "app" {
  name                 = "app-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.app.name
  address_prefixes     = ["10.2.1.0/24"]
}

resource "azurerm_subnet" "sql_pe" {
  name                 = "private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.sql.name
  address_prefixes     = ["10.3.1.0/24"]
  private_endpoint_network_policies = "Enabled"
}

# Hub/spoke peering. Allow forwarded traffic for Azure Firewall inspection.
resource "azurerm_virtual_network_peering" "hub_web" {
  name                      = "hub-to-web"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.web.id
  allow_forwarded_traffic   = true
  allow_virtual_network_access = true
}
resource "azurerm_virtual_network_peering" "web_hub" {
  name                      = "web-to-hub"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.web.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  allow_virtual_network_access = true
}
resource "azurerm_virtual_network_peering" "hub_app" {
  name                      = "hub-to-app"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.app.id
  allow_forwarded_traffic   = true
  allow_virtual_network_access = true
}
resource "azurerm_virtual_network_peering" "app_hub" {
  name                      = "app-to-hub"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.app.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  allow_virtual_network_access = true
}
resource "azurerm_virtual_network_peering" "hub_sql" {
  name                      = "hub-to-sqldb"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.sql.id
  allow_forwarded_traffic   = true
  allow_virtual_network_access = true
}
resource "azurerm_virtual_network_peering" "sql_hub" {
  name                      = "sqldb-to-hub"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.sql.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  allow_virtual_network_access = true
}

# ----------------------------- Routing ----------------------------------------
# Every spoke sends Internet and inter-spoke traffic through the firewall.
resource "azurerm_route_table" "web" {
  name                = "${var.name_prefix}-web-rt"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  bgp_route_propagation_enabled = false
  tags = var.tags
}
resource "azurerm_route_table" "app" {
  name                = "${var.name_prefix}-app-rt"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  bgp_route_propagation_enabled = false
  tags = var.tags
}
resource "azurerm_route_table" "sql" {
  name                = "${var.name_prefix}-sql-rt"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  bgp_route_propagation_enabled = false
  tags = var.tags
}

locals {
  spoke_routes = {
    web = {
      vnet = azurerm_virtual_network.web.name
      rt   = azurerm_route_table.web.name
      rg   = azurerm_resource_group.main.name
      peers = ["10.2.0.0/16", "10.3.0.0/16"]
    }
    app = {
      vnet = azurerm_virtual_network.app.name
      rt   = azurerm_route_table.app.name
      rg   = azurerm_resource_group.main.name
      peers = ["10.1.0.0/16", "10.3.0.0/16"]
    }
    sql = {
      vnet = azurerm_virtual_network.sql.name
      rt   = azurerm_route_table.sql.name
      rg   = azurerm_resource_group.main.name
      peers = ["10.1.0.0/16", "10.2.0.0/16"]
    }
  }
}

resource "azurerm_route" "default_web" {
  name                   = "default-to-firewall"
  resource_group_name    = azurerm_resource_group.main.name
  route_table_name       = azurerm_route_table.web.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
}
resource "azurerm_route" "default_app" {
  name                   = "default-to-firewall"
  resource_group_name    = azurerm_resource_group.main.name
  route_table_name       = azurerm_route_table.app.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
}
resource "azurerm_route" "default_sql" {
  name                   = "default-to-firewall"
  resource_group_name    = azurerm_resource_group.main.name
  route_table_name       = azurerm_route_table.sql.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

resource "azurerm_route" "web_to_peer" {
  for_each               = toset(["10.2.0.0/16", "10.3.0.0/16"])
  name                   = "inspect-${replace(each.value, "/", "-")}"
  resource_group_name    = azurerm_resource_group.main.name
  route_table_name       = azurerm_route_table.web.name
  address_prefix         = each.value
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
}
resource "azurerm_route" "app_to_peer" {
  for_each               = toset(["10.1.0.0/16", "10.3.0.0/16"])
  name                   = "inspect-${replace(each.value, "/", "-")}"
  resource_group_name    = azurerm_resource_group.main.name
  route_table_name       = azurerm_route_table.app.name
  address_prefix         = each.value
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
}
resource "azurerm_route" "sql_to_peer" {
  for_each               = toset(["10.1.0.0/16", "10.2.0.0/16"])
  name                   = "inspect-${replace(each.value, "/", "-")}"
  resource_group_name    = azurerm_resource_group.main.name
  route_table_name       = azurerm_route_table.sql.name
  address_prefix         = each.value
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "web" {
  subnet_id      = azurerm_subnet.web.id
  route_table_id = azurerm_route_table.web.id
}
resource "azurerm_subnet_route_table_association" "app" {
  subnet_id      = azurerm_subnet.app.id
  route_table_id = azurerm_route_table.app.id
}
resource "azurerm_subnet_route_table_association" "sql" {
  subnet_id      = azurerm_subnet.sql_pe.id
  route_table_id = azurerm_route_table.sql.id
}

# ----------------------------- Network Security Groups ------------------------
resource "azurerm_network_security_group" "web" {
  name                = "${var.name_prefix}-web-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags = var.tags
}
resource "azurerm_network_security_rule" "web_from_waf" {
  name                        = "Allow-HTTPS-from-AppGateway"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "10.0.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.web.name
}
resource "azurerm_network_security_rule" "web_deny_other_vnet" {
  name                        = "Deny-other-VNet-inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.web.name
}
resource "azurerm_network_security_group" "app" {
  name                = "${var.name_prefix}-app-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags = var.tags
}
resource "azurerm_network_security_rule" "app_from_web" {
  name                        = "Allow-Web-to-App-8080"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = "10.1.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}
resource "azurerm_network_security_rule" "app_deny_other_vnet" {
  name                        = "Deny-other-VNet-inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}
resource "azurerm_network_security_group" "sql" {
  name                = "${var.name_prefix}-sqldb-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags = var.tags
}
resource "azurerm_network_security_rule" "sql_from_app" {
  name                        = "Allow-App-to-SQL-1433"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "10.2.1.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.sql.name
}
resource "azurerm_network_security_rule" "sql_deny_web" {
  name                        = "Deny-Web-to-SQLDB"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.1.0.0/16"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.sql.name
}
resource "azurerm_network_security_rule" "sql_deny_other_vnet" {
  name                        = "Deny-other-VNet-inbound"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.sql.name
}
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}
resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}
resource "azurerm_subnet_network_security_group_association" "sql" {
  subnet_id                 = azurerm_subnet.sql_pe.id
  network_security_group_id = azurerm_network_security_group.sql.id
}

# ----------------------------- Workload VMs -----------------------------------
# Demonstration Linux VMs have private NICs only. Use your own golden images in production.
resource "azurerm_network_interface" "web" {
  name                = "${var.name_prefix}-web-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.web_vm_ip
  }
  tags = var.tags
}
resource "azurerm_network_interface" "app" {
  name                = "${var.name_prefix}-app-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.app.id
    private_ip_address_allocation = "Static"
    private_ip_address            = local.app_vm_ip
  }
  tags = var.tags
}
resource "azurerm_linux_virtual_machine" "web" {
  name                            = "${var.name_prefix}-web-01"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_B2s"
  admin_username                  = var.admin_username
  network_interface_ids           = [azurerm_network_interface.web.id]
  disable_password_authentication = true
  zone                            = "1"
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  custom_data = base64encode(<<-CLOUDINIT
    #cloud-config
    package_update: true
    packages:
      - nginx
    runcmd:
      - [bash, -lc, "echo '<h1>Web tier is running</h1>' > /var/www/html/index.html"]
      - [systemctl, enable, --now, nginx]
  CLOUDINIT
  )
  tags = var.tags
}
resource "azurerm_linux_virtual_machine" "app" {
  name                            = "${var.name_prefix}-app-01"
  resource_group_name             = azurerm_resource_group.main.name
  location                        = azurerm_resource_group.main.location
  size                            = "Standard_B2s"
  admin_username                  = var.admin_username
  network_interface_ids           = [azurerm_network_interface.app.id]
  disable_password_authentication = true
  zone                            = "1"
  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  custom_data = base64encode(<<-CLOUDINIT
    #cloud-config
    package_update: true
    packages:
      - python3
    write_files:
      - path: /opt/app.py
        permissions: '0755'
        content: |
          from http.server import BaseHTTPRequestHandler, HTTPServer
          class H(BaseHTTPRequestHandler):
              def do_GET(self):
                  self.send_response(200)
                  self.send_header('Content-type','text/plain')
                  self.end_headers()
                  self.wfile.write(b'Application tier is running')
          HTTPServer(('0.0.0.0',8080),H).serve_forever()
      - path: /etc/systemd/system/demo-app.service
        content: |
          [Unit]
          Description=Demo application
          After=network.target
          [Service]
          ExecStart=/usr/bin/python3 /opt/app.py
          Restart=always
          [Install]
          WantedBy=multi-user.target
    runcmd:
      - [systemctl, daemon-reload]
      - [systemctl, enable, --now, demo-app]
  CLOUDINIT
  )
  tags = var.tags
}

# ----------------------------- Application Gateway WAF ------------------------
resource "azurerm_public_ip" "appgw" {
  name                = "${var.name_prefix}-appgw-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags = var.tags
}

resource "azurerm_application_gateway" "main" {
  name                = "${var.name_prefix}-appgw-waf"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  zones               = ["1", "2", "3"]
  enable_http2        = true
  firewall_policy_id  = azurerm_web_application_firewall_policy.main.id
  tags = var.tags

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.app_gateway.id
  }

  frontend_ip_configuration {
    name                 = "public-frontend"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  frontend_port {
    name = "https"
    port = 443
  }

  ssl_certificate {
    name     = "bootstrap-self-signed"
    data     = var.tls_certificate_pfx_base64
    password = var.tls_certificate_password
  }

  http_listener {
    name                           = "https-listener"
    frontend_ip_configuration_name = "public-frontend"
    frontend_port_name             = "https"
    protocol                       = "Https"
    ssl_certificate_name           = "bootstrap-self-signed"
  }

  backend_address_pool {
    name         = "web-backend"
    ip_addresses = [local.web_vm_ip]
  }

  backend_http_settings {
    name                  = "web-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "web-health"
  }

  probe {
    name                = "web-health"
    protocol            = "Http"
    path                = "/"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    match {
      status_code = ["200-399"]
    }
  }

  request_routing_rule {
    name                       = "https-to-web"
    rule_type                  = "Basic"
    http_listener_name         = "https-listener"
    backend_address_pool_name  = "web-backend"
    backend_http_settings_name = "web-http"
    priority                   = 100
  }
}

resource "azurerm_web_application_firewall_policy" "main" {
  name                = "${var.name_prefix}-waf-policy"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags = var.tags

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }
}

# ----------------------------- Azure SQL + Private Endpoint --------------------
resource "azurerm_mssql_server" "main" {
  name                         = local.names.sql_server
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password
  minimum_tls_version          = "1.2"
  public_network_access_enabled = false
  tags = var.tags
}

resource "azurerm_mssql_database" "main" {
  name           = "${var.name_prefix}-appdb"
  server_id      = azurerm_mssql_server.main.id
  sku_name       = "S0"
  max_size_gb    = 10
  zone_redundant = false
  tags = var.tags
}

resource "azurerm_private_dns_zone" "sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.main.name
  tags = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  name                  = "sql-dns-hub"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "web" {
  name                  = "sql-dns-web"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.web.id
  registration_enabled  = false
  tags = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "app" {
  name                  = "sql-dns-app"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.app.id
  registration_enabled  = false
  tags = var.tags
}
resource "azurerm_private_dns_zone_virtual_network_link" "sql" {
  name                  = "sql-dns-sqldb"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.sql.name
  virtual_network_id    = azurerm_virtual_network.sql.id
  registration_enabled  = false
  tags = var.tags
}

resource "azurerm_private_endpoint" "sql" {
  name                = "${var.name_prefix}-sql-pe"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.sql_pe.id
  private_service_connection {
    name                           = "sql-private-connection"
    private_connection_resource_id = azurerm_mssql_server.main.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }
  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql.id]
  }
  tags = var.tags
}

# ----------------------------- Diagnostics ------------------------------------
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "firewall-diagnostics"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "AzureFirewallApplicationRule" }
  enabled_log { category = "AzureFirewallNetworkRule" }
  enabled_log { category = "AzureFirewallDnsProxy" }
  metric { category = "AllMetrics" }
}
resource "azurerm_monitor_diagnostic_setting" "appgw" {
  name                       = "appgw-diagnostics"
  target_resource_id         = azurerm_application_gateway.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "ApplicationGatewayAccessLog" }
  enabled_log { category = "ApplicationGatewayPerformanceLog" }
  enabled_log { category = "ApplicationGatewayFirewallLog" }
  metric { category = "AllMetrics" }
}
resource "azurerm_monitor_diagnostic_setting" "sql" {
  name                       = "sql-diagnostics"
  target_resource_id         = azurerm_mssql_database.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log { category = "SQLInsights" }
  enabled_log { category = "AutomaticTuning" }
  enabled_log { category = "QueryStoreRuntimeStatistics" }
  enabled_log { category = "Errors" }
  metric { category = "AllMetrics" }
}
