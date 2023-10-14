provider "azurerm" {
    subscription_id = "xxxxxxb"
	client_id       = "xxxxxxxxxx"
	client_secret   = "xxxxxx"
	tenant_id       = "xxxxxxx"
	 features {}
    #skip_provider_registration = true 
}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "example" {
  name                = var.vnet_name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "example" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = [var.subnet_address]
}

resource "azurerm_network_interface" "example" {
  count               = var.vm_count
  name                = "${var.vm_prefix}-${count.index}-NIC"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "myNICConfig"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
  }
  depends_on = [
    azurerm_virtual_network.example,
    azurerm_subnet.example
  ]
}

resource "azurerm_virtual_machine" "example" {
  count               = var.vm_count
  name                = "${var.vm_prefix}-${count.index}-VM"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  network_interface_ids = [azurerm_network_interface.example[count.index].id]
  vm_size             = var.vm_size
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = var.os_publisher
    offer     = var.os_offer
    sku       = var.os_sku
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.vm_prefix}-${count.index}-OsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    computer_name  = "${var.vm_prefix}-${count.index}"
    admin_username = var.admin_username
    admin_password = var.admin_password
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

resource "azurerm_lb" "example" {
  name                = var.lb_name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  frontend_ip_configuration {
    name                 = var.lb_frontend_name
    public_ip_address_id = azurerm_public_ip.example.id
  }
}

resource "azurerm_public_ip" "example" {
  name                = var.public_ip_name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Dynamic"
}

resource "azurerm_lb_backend_address_pool" "example" {
  name                = "myBackendAddressPool"
  loadbalancer_id     = azurerm_lb.example.id
}

resource "azurerm_lb_nat_rule" "example" {
  count               = var.vm_count
  name                = "myNatRule-${count.index}"
  protocol            = "Tcp"
  frontend_port       = count.index * 10 + 50000
  backend_port        = 22
  frontend_ip_configuration_id = azurerm_lb.example.frontend_ip_configuration[0].id
  loadbalancer_id     = azurerm_lb.example.id
  resource_group_name = azurerm_resource_group.example.name
  backend_address_pool_id = azurerm_lb_backend_address_pool.example.id
  frontend_ip_configuration_name = var.frontend_ip_configuration_name
}
