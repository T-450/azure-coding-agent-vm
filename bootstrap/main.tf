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
  }
}

provider "azurerm" {
  features {}
}

# Random suffix for globally unique storage account name
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location
  tags = {
    project     = "terraform-state"
    managed_by  = "terraform"
    environment = "bootstrap"
  }
}

locals {
  storage_account_name = var.storage_account_name != "" ? var.storage_account_name : "tfstate${random_string.suffix.result}"
}

resource "azurerm_storage_account" "state" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags = {
    project    = "terraform-state"
    managed_by = "terraform"
  }
}

resource "azurerm_storage_container" "state" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}
