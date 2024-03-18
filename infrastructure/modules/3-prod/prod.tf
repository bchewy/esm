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

resource "azurerm_subnet" "odoo-subnet-db" {
  name                 = "odoo-prod-db-subnet"
  resource_group_name  = azurerm_resource_group.odoo-rg.name
  virtual_network_name = azurerm_virtual_network.odoo-vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "postgresqlDelegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
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
    # public_ip_address_id          = azurerm_public_ip.odoo-prod-vm-pip.id
  }
}

resource "azurerm_network_security_group" "odoo-prod-nsg" {
  name                = "odoo-prod-nsg"
  location            = azurerm_resource_group.odoo-rg.location
  resource_group_name = azurerm_resource_group.odoo-rg.name

  security_rule {
    name                       = "HTTP"
    priority                   = 1006
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1007
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "ODOO-ACCESS"
    priority                   = 1008
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8069"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "POSTGRES"
    priority                   = 1009
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "OUTBOUND-FOR-ODOO"
    priority                   = 1010
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8069"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }




}

resource "azurerm_subnet_network_security_group_association" "odoo-prod-subnet-nsg-association" {
  subnet_id                 = azurerm_subnet.odoo-subnet.id
  network_security_group_id = azurerm_network_security_group.odoo-prod-nsg.id
}


# VIRTUAL MACHINE CONTROL - IF ALL ELSE FAILS
# resource "azurerm_linux_virtual_machine" "odoo-prod-vm" {
#   name                = "odoo-prod-vm"
#   resource_group_name = azurerm_resource_group.odoo-rg.name
#   location            = azurerm_resource_group.odoo-rg.location
#   size                = "Standard_D2s_v3"

#   admin_username                  = "is214"
#   admin_password                  = "brian134!"
#   disable_password_authentication = false

#   network_interface_ids = [azurerm_network_interface.odoo-nic.id]

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Premium_LRS"
#     // disk_size_gb      = <specify-if-required>
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "0001-com-ubuntu-server-jammy"
#     sku       = "22_04-lts"
#     version   = "latest"
#   }

#   custom_data = filebase64("user_data.sh")
# }

# resource "azurerm_backup_policy_vm" "odoo-prod-vm-backup" {
#   name                = "odoo-prod-vm-backup"
#   resource_group_name = azurerm_resource_group.odoo-rg.name
#   recovery_vault_name = azurerm_recovery_services_vault.odoo-prod-recovery-vault.name

#   backup {
#     frequency = "Daily"
#     time      = "23:00"
#   }
#   retention_daily {
#     count = 30
#   }
# }

# WARN: Deleting the azurerm_recovery_services_vault can cause more of an issue - to fully delete use the pshell script provided on Azure Console.
# resource "azurerm_recovery_services_vault" "odoo-prod-recovery-vault" {
#   name                = "odoo-prod-recovery-vault"
#   location            = azurerm_resource_group.odoo-rg.location
#   resource_group_name = azurerm_resource_group.odoo-rg.name
#   sku                 = "Standard"
#   soft_delete_enabled = false


# }
# resource "azurerm_backup_protected_vm" "odoo-prod-vm-backup" {
#   resource_group_name = azurerm_resource_group.odoo-rg.name
#   recovery_vault_name = azurerm_recovery_services_vault.odoo-prod-recovery-vault.name
#   source_vm_id        = azurerm_linux_virtual_machine.odoo-prod-vm.id
#   backup_policy_id    = azurerm_backup_policy_vm.odoo-prod-vm-backup.id
# }



# PUBLIC IPS

resource "azurerm_public_ip" "odoo-prod-vm-pip" {
  name                = "odoo-prod-vm-publicip"
  location            = azurerm_resource_group.odoo-rg.location
  resource_group_name = azurerm_resource_group.odoo-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "odoo-prod-lb-pip" {
  name                = "odoo-prod-publicip"
  location            = azurerm_resource_group.odoo-rg.location
  resource_group_name = azurerm_resource_group.odoo-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# LOAD BALANCER

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
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_outbound_rule" "odoo-outbound-rule" {
  name                    = "odoo-outbound-rule"
  loadbalancer_id         = azurerm_lb.odoo-prod-lb.id
  protocol                = "All"
  backend_address_pool_id = azurerm_lb_backend_address_pool.odoo-prod-bap.id
  # idle_timeout_in_minutes = 4
  # enable_tcp_reset        = false
  frontend_ip_configuration {
    name = "odoo-prod-lb-frontip"
  }

}

# HTTP Load Balancer rule is here
resource "azurerm_lb_rule" "odoo-frontend-http-rule" {
  name                           = "odoo-frontend-http-rule"
  loadbalancer_id                = azurerm_lb.odoo-prod-lb.id
  protocol                       = "Tcp"
  frontend_port                  = 8069
  backend_port                   = 8069
  frontend_ip_configuration_name = "odoo-prod-lb-frontip"
  disable_outbound_snat          = true
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.odoo-prod-bap.id]
  probe_id                       = azurerm_lb_probe.odoo-prod-lb-probe.id

}

# VMSS
resource "azurerm_linux_virtual_machine_scale_set" "odoo-prod-vmss" {
  name                            = "odoo-prod-vmss"
  resource_group_name             = azurerm_resource_group.odoo-rg.name
  location                        = azurerm_resource_group.odoo-rg.location
  sku                             = "Standard_D2s_v3"
  instances                       = 1
  admin_username                  = "is214"
  admin_password                  = "brian134!"
  disable_password_authentication = false

  custom_data = filebase64("user_data.sh")

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



#  postgres deployment
resource "azurerm_postgresql_flexible_server" "postgres_instance" {
  name                   = "odoo-pogstgres-prod"
  resource_group_name    = azurerm_resource_group.odoo-rg.name
  location               = azurerm_resource_group.odoo-rg.location
  version                = "12"
  delegated_subnet_id    = azurerm_subnet.odoo-subnet-db.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres_private_dns_zone.id
  administrator_login    = "is214"
  administrator_password = "brian134!"
  # zone                   = "1" #Disable this for now, capacities for flexible in zone 1

  storage_mb   = 32768
  storage_tier = "P30"

  sku_name = "GP_Standard_D2s_v3"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  server_id        = azurerm_postgresql_flexible_server.postgres_instance.id
  name             = "allow-all"
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}


resource "azurerm_private_dns_zone" "postgres_private_dns_zone" {
  name                = "odoobchewy.postgres.database.azure.com" # Standard domain for Azure Database for PostgreSQL
  resource_group_name = azurerm_resource_group.odoo-rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres_dns_vnet_link" {
  name                  = "postgres-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres_private_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.odoo-vnet.id
  resource_group_name   = azurerm_resource_group.odoo-rg.name
}
