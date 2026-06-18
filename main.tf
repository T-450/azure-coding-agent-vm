terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # Remote state backend (Azure Storage).
  # Bootstrap first with bootstrap/ directory, then uncomment and run:
  #   terraform init -reconfigure -migrate-state
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "tfstate<random>"
  #   container_name       = "tfstate"
  #   key                  = "coding-agent-vm.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.vm_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "main" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_address_prefix]
}

# ---------------------------------------------------------------------------
# Public IP (optional -- set create_public_ip = false if using VPN/Bastion)
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "main" {
  count = var.create_public_ip ? 1 : 0

  name                = "pip-${var.vm_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.vm_name}-${random_string.suffix.result}"
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Network Security Group
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "main" {
  name                = "nsg-${var.vm_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  # When Cloudflare Tunnel is configured: no inbound ports at all.
  # The VM initiates an outbound-only connection to Cloudflare's edge,
  # and you connect through Cloudflare (cloudflared access ssh).
  # When not using Cloudflare: SSH locked to your VPN egress IP.

  dynamic "security_rule" {
    for_each = var.cloudflare_tunnel_token == "" ? [1] : []
    content {
      name                       = "AllowSSH"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = var.ssh_allowed_ip
      destination_address_prefix = "*"
    }
  }

  # Deny all other inbound
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "main" {
  name                = "nic-${var.vm_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.create_public_ip ? azurerm_public_ip.main[0].id : null
  }
}

resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# ---------------------------------------------------------------------------
# SSH Key (from local file)
# ---------------------------------------------------------------------------
data "local_file" "ssh_public_key" {
  filename = pathexpand(var.ssh_public_key_path)
}

# ---------------------------------------------------------------------------
# Cloud-init template
# ---------------------------------------------------------------------------
locals {
  cloud_init_rendered = templatefile("${path.module}/cloud-init.yaml", {
    admin_username          = var.admin_username
    docker_disk_device      = var.docker_disk_size_gb > 0 ? "/dev/sdc" : ""
    docker_disk_size_gb     = var.docker_disk_size_gb
    cloudflare_tunnel_token = var.cloudflare_tunnel_token
  })
}

# ---------------------------------------------------------------------------
# Virtual Machine
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "agent" {
  name                  = var.vm_name
  location              = azurerm_resource_group.main.location
  resource_group_name   = azurerm_resource_group.main.name
  size                  = var.vm_size
  admin_username        = var.admin_username
  custom_data           = base64encode(local.cloud_init_rendered)
  network_interface_ids = [azurerm_network_interface.main.id]
  tags                  = var.tags

  admin_ssh_key {
    username   = var.admin_username
    public_key = data.local_file.ssh_public_key.content
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.disk_type
    disk_size_gb         = var.disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = var.ubuntu_version
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  # Boot diagnostics for troubleshooting
  boot_diagnostics {
    storage_account_uri = null # uses managed storage
  }
}

# ---------------------------------------------------------------------------
# Optional: additional data disk for Docker storage
# ---------------------------------------------------------------------------
resource "azurerm_managed_disk" "docker" {
  count = var.docker_disk_size_gb > 0 ? 1 : 0

  name                 = "disk-${var.vm_name}-docker"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "StandardSSD_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.docker_disk_size_gb
  tags                 = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "docker" {
  count = var.docker_disk_size_gb > 0 ? 1 : 0

  managed_disk_id    = azurerm_managed_disk.docker[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.agent.id
  lun                = 0
  caching            = "ReadWrite"
}

# ---------------------------------------------------------------------------
# Optional: Azure Monitor / VM Insights
# ---------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  count = var.enable_azure_monitor ? 1 : 0

  name                = "log-${var.vm_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Validation checks (run during plan and apply)
# ---------------------------------------------------------------------------

check "ssh_not_wildcard" {
  assert {
    condition     = var.ssh_allowed_ip != "0.0.0.0/0"
    error_message = "CRITICAL: ssh_allowed_ip is set to 0.0.0.0/0 (world-open). Lock it to your VPN egress IP."
  }
}

check "cloudflare_or_ssh_locked" {
  assert {
    condition     = var.cloudflare_tunnel_token != "" || var.ssh_allowed_ip != "0.0.0.0/0"
    error_message = "Either configure Cloudflare Tunnel (zero inbound ports) or lock ssh_allowed_ip to a specific IP range."
  }
}

check "disk_size_adequate" {
  assert {
    condition     = var.disk_size_gb >= 40
    error_message = "OS disk should be at least 40GB. Docker images + monorepos need space."
  }
}

check "vm_size_not_too_small" {
  assert {
    condition     = can(regex("Standard_B[2-9]|Standard_D|Standard_E", var.vm_size))
    error_message = "VM size ${var.vm_size} may be too small. B2s (2 vCPU, 4GB) is the minimum recommended."
  }
}
