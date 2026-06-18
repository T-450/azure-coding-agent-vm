output "resource_group_name" {
  value = azurerm_resource_group.state.name
}

output "storage_account_name" {
  value = azurerm_storage_account.state.name
}

output "container_name" {
  value = azurerm_storage_container.state.name
}

output "backend_config" {
  description = "Paste this block into the main project's terraform block to enable remote state"
  value = <<-EOT
    backend "azurerm" {
      resource_group_name  = "${azurerm_resource_group.state.name}"
      storage_account_name = "${azurerm_storage_account.state.name}"
      container_name       = "${azurerm_storage_container.state.name}"
      key                  = "coding-agent-vm.tfstate"
    }
  EOT
}

output "bootstrap_command" {
  description = "How to bootstrap the state backend"
  value = <<-EOT
    cd bootstrap
    terraform init
    terraform apply -auto-approve
    terraform output backend_config
    # Copy the backend block into the root main.tf, then:
    cd ..
    terraform init -reconfigure -migrate-state
  EOT
}
