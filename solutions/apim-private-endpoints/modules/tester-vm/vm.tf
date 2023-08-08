resource "azurerm_public_ip" "tester-pip" {
allocation_method = "Dynamic"
name                = "pip-${var.name}-tester" 
resource_group_name = var.resource_group
location            = var.location

}

resource "azurerm_network_interface" "tester" {
  name                = "nic-${var.name}-tester"
  location            = var.location
  resource_group_name = var.resource_group

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.tester-pip.id
  }
}

resource "azurerm_linux_virtual_machine" "tester" {
  name                = "vm-${var.name}-tester"
  resource_group_name = var.resource_group
  location            = var.location
  size                = "Standard_B4ms"
  admin_username      = "tjs"
  network_interface_ids = [
    azurerm_network_interface.tester.id,
  ]

  admin_ssh_key {
    username   = "tjs"
    public_key = file(var.ssh_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-LTS"
    version   = "latest"
  }
}