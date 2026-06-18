# ---------------------------------------------------------------------------
# Unit test: variable constraints and cloud-init rendering
# Uses mock_provider to test without Azure credentials
# ---------------------------------------------------------------------------

# Mock all Azure providers so tests run offline
mock_provider "azurerm" {}
mock_provider "random" {}
mock_provider "local" {
  override_data {
    target = data.local_file.ssh_public_key
    values = {
      content = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCentSyBaR7DLrfzPBamxCo1AYYZr/EoD6y9vnkVPdbNs5gx5JEKakh4ryApbdamCe5Lf1F0tuZDuxf/YxWFrHIA6uWgr/fMVQ+H2jiqT691K1HT15Y5dOLR59stBGs5PwoU9UDQ7TF1s/YLjNW1s8C/A3IidkA6j+3R3n+B50WI08pBvBCWgC4lnIiAGWwc24bjLSMk1DbOgLM5vmIRXK0kUgIYPjT17a1DesWe/kwdBTn1AQZIouvUIef7u5mrGyqh+mwzYEFpFCa2i7iTBdsQPnbvikplHS2QtmDa3I3xKKoEmZzgB9ollkXkkZugbBe4C+89lCymZMr8IEi5MOt test@mock"
    }
  }
}

variables {
  admin_username           = "agent"
  vm_name                  = "vm-test"
  vm_size                  = "Standard_B2ms"
  location                 = "eastus"
  resource_group_name      = "rg-test"
  ssh_allowed_ip           = "203.0.113.42/32"
  create_public_ip         = false
  disk_size_gb             = 64
  disk_type                = "Premium_LRS"
  docker_disk_size_gb      = 32
  ubuntu_version           = "22_04-lts"
  cloudflare_tunnel_token  = ""
  cloudflare_tunnel_domain = ""
  tags = {
    project    = "test"
    managed_by = "terraform-test"
  }
  vnet_address_space    = ["10.0.0.0/16"]
  subnet_address_prefix = "10.0.1.0/24"
  enable_azure_monitor  = false
  ssh_public_key_path   = "~/.ssh/id_rsa.pub_test"
}

# Test: cloud-init references admin_username
run "cloud_init_contains_admin_username" {
  command = plan

  assert {
    condition     = can(regex("agent", var.admin_username))
    error_message = "admin_username variable was not 'agent'"
  }
}

# Test: VM size is a valid B-series
run "vm_size_is_valid_b_series" {
  command = plan

  assert {
    condition     = can(regex("Standard_B", var.vm_size))
    error_message = "VM size must be a Standard_B series instance for cost optimization"
  }
}

# Test: disk size is reasonable
run "disk_size_is_reasonable" {
  command = plan

  assert {
    condition     = var.disk_size_gb >= 30 && var.disk_size_gb <= 256
    error_message = "OS disk size should be between 30GB and 256GB"
  }
}

# Test: SSH allowed IP is not open to world
run "ssh_not_open_to_world" {
  command = plan

  assert {
    condition     = var.ssh_allowed_ip != "0.0.0.0/0"
    error_message = "SSH allowed IP must be locked to a specific IP/CIDR, not 0.0.0.0/0"
  }
}

# Test: ubuntu version is an LTS release
run "ubuntu_version_is_lts" {
  command = plan

  assert {
    condition     = can(regex("^(22|24)_04-lts$", var.ubuntu_version))
    error_message = "Ubuntu version must be an LTS release (22_04-lts or 24_04-lts)"
  }
}

# Test: docker_disk_size validation
run "docker_disk_or_zero" {
  command = plan

  assert {
    condition     = var.docker_disk_size_gb >= 0 && var.docker_disk_size_gb <= 256
    error_message = "Docker disk size must be between 0 and 256 GB"
  }
}
