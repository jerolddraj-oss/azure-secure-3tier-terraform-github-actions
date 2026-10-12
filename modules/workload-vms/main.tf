resource "azurerm_network_interface" "web" {
  name = "${var.name_prefix}-web-nic"
  location = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name = "internal"
    subnet_id = var.web_subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address = var.web_private_ip
  }
  tags = var.tags
}
resource "azurerm_network_interface" "app" {
  name = "${var.name_prefix}-app-nic"
  location = var.location
  resource_group_name = var.resource_group_name
  ip_configuration {
    name = "internal"
    subnet_id = var.app_subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address = var.app_private_ip
  }
  tags = var.tags
}
resource "azurerm_linux_virtual_machine" "web" {
  name = "${var.name_prefix}-web-01"
  location = var.location
  resource_group_name = var.resource_group_name
  size = var.vm_size
  admin_username = var.admin_username
  network_interface_ids = [azurerm_network_interface.web.id]
  disable_password_authentication = true
  admin_ssh_key {
    username = var.admin_username
    public_key = var.ssh_public_key
  }
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer = "0001-com-ubuntu-server-jammy"
    sku = "22_04-lts-gen2"
    version = "latest"
  }
  custom_data = base64encode("#cloud-config\npackages: [nginx]\nruncmd:\n - [bash, -lc, \"echo '<h1>Web tier is running</h1>' > /var/www/html/index.html\"]\n - [systemctl, enable, --now, nginx]\n")
  tags = var.tags
}
resource "azurerm_linux_virtual_machine" "app" {
  name = "${var.name_prefix}-app-01"
  location = var.location
  resource_group_name = var.resource_group_name
  size = var.vm_size
  admin_username = var.admin_username
  network_interface_ids = [azurerm_network_interface.app.id]
  disable_password_authentication = true
  admin_ssh_key {
    username = var.admin_username
    public_key = var.ssh_public_key
  }
  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer = "0001-com-ubuntu-server-jammy"
    sku = "22_04-lts-gen2"
    version = "latest"
  }
  custom_data = base64encode("#cloud-config\npackages: [python3]\nwrite_files:\n - path: /opt/app.py\n   permissions: '0755'\n   content: |\n     from http.server import BaseHTTPRequestHandler, HTTPServer\n     class H(BaseHTTPRequestHandler):\n       def do_GET(self):\n         self.send_response(200); self.end_headers(); self.wfile.write(b'Application tier is running')\n     HTTPServer(('0.0.0.0',8080),H).serve_forever()\nruncmd:\n - [bash, -lc, \"python3 /opt/app.py >/var/log/demo-app.log 2>&1 &\"]\n")
  tags = var.tags
}
