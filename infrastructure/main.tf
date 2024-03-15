provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "6d07e33b-f071-4121-9c74-7c575bafc191"
}

resource "azurerm_resource_group" "odoo-rg" {
  name     = "odoo-prod-rg"
  location = "West US"
}

resource "azurerm_virtual_network" "odoo-vnet" {
  name                = "odoo-prod-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.odoo-rg.location
  resource_group_name = azurerm_resource_group.odoo-rg.name
}

resource "azurerm_subnet" "odoo-subnet" {
  name                 = "odoo-prod-subnet"
  resource_group_name  = azurerm_resource_group.odoo-rg.name
  virtual_network_name = azurerm_virtual_network.odoo-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "odoo-nic" {
  name                = "odoo-prod-nic"
  location            = azurerm_resource_group.odoo-rg.location
  resource_group_name = azurerm_resource_group.odoo-rg.name

  ip_configuration {
    name                          = "odoo-prod-nic-ip"
    subnet_id                     = azurerm_subnet.odoo-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


resource "azurerm_virtual_machine" "odoo-prod-vm" {
  name                  = "my-virtual-machine"
  location              = azurerm_resource_group.odoo-rg.location
  resource_group_name   = azurerm_resource_group.odoo-rg.name
  network_interface_ids = [azurerm_network_interface.odoo-nic.id]
  vm_size               = "Standard_D2s_v3"

  storage_os_disk {
    name              = "odoo-prod-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    // Add disk_size_gb if you want to specify the size of the OS disk
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts" // This SKU is an example; adjust based on availability
    version   = "latest"
  }

  os_profile {
    computer_name  = "odoo-prod-vm"
    admin_username = "is214"
    admin_password = "brian134!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
    // If you want to use SSH keys for authentication, set the above to true and provide the ssh_keys block
  }

  # boot_diagnostics {
  #   enabled     = false
  #   storage_uri = azurerm_storage_account.example.primary_blob_endpoint
  # }
}


resource "azurerm_public_ip" "odoo-prod-lb-pip" {
  name                = "odoo-prod-publicip"
  location            = azurerm_resource_group.odoo-rg.location
  resource_group_name = azurerm_resource_group.odoo-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "odoo-prod-lb" {
  name                = "odoo-prod-lb"
  location            = azurerm_resource_group.odoo-rg.location
  resource_group_name = azurerm_resource_group.odoo-rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "odoo-prod-lb-frontip"
    public_ip_address_id = azurerm_public_ip.odoo-prod-lb-pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "odoo-prod-bap" {
  name            = "odoo-prod-lb-backendpool"
  loadbalancer_id = azurerm_lb.odoo-prod-lb.id
}

resource "azurerm_lb_probe" "odoo-prod-lb-probe" {
  name                = "odoo-prod-lb-probe"
  loadbalancer_id     = azurerm_lb.odoo-prod-lb.id
  protocol            = "Http"
  port                = 8069
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

# resource "azurerm_lb_rule" "odoo-prod-lb-rule" {
#   name                           = "odoo-prod-lbrule"
#   loadbalancer_id                = azurerm_lb.odoo-prod-lb.id
#   protocol                       = "Tcp"
#   frontend_port                  = 8069
#   backend_port                   = 8069
#   frontend_ip_configuration_name = "odoo-prod-lb-frontip"
#   probe_id                       = azurerm_lb_probe.odoo-prod-lb-probe.id
# }

resource "azurerm_lb_rule" "odoo-frontend-http-rule" {
  name                           = "odoo-frontend-http-rule"
  loadbalancer_id                = azurerm_lb.odoo-prod-lb.id
  protocol                       = "Tcp"
  frontend_port                  = 8069
  backend_port                   = 8069 // Assuming your VM serves HTTP traffic on port 80; adjust if different.
  frontend_ip_configuration_name = "odoo-prod-lb-frontip"
  // probe_id is optional, depends if you have a specific health check for HTTP
}


# create virtual machine scale sets to be placed in front of my our frontend load balancer here:
resource "azurerm_linux_virtual_machine_scale_set" "odoo-prod-vmss" {
  name                = "odoo-prod-vmss"
  resource_group_name = azurerm_resource_group.odoo-rg.name
  location            = azurerm_resource_group.odoo-rg.location
  sku                 = "Standard_D2s_v3"
  instances           = 2
  admin_username      = "is214"
  admin_password      = "brian134!"

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "odoo-prod-vmss-nic"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.odoo-subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.odoo-prod-bap.id]
    }
  }
}




