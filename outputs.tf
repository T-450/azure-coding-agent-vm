output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = azurerm_linux_virtual_machine.agent.name
}

output "vm_id" {
  description = "Azure VM resource ID"
  value       = azurerm_linux_virtual_machine.agent.id
}

output "vm_private_ip" {
  description = "Private IP address (use this over VPN)"
  value       = azurerm_network_interface.main.private_ip_addresses[0]
}

output "vm_public_ip" {
  description = "Public IP address (if created). Lock NSG to your VPN IP"
  value       = var.create_public_ip ? azurerm_public_ip.main[0].ip_address : null
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value = var.create_public_ip ? (
    "ssh ${var.admin_username}@${azurerm_public_ip.main[0].ip_address}"
  ) : (
    "ssh ${var.admin_username}@${azurerm_network_interface.main.private_ip_addresses[0]}  (over VPN)"
  )
}

output "vscode_ssh_command" {
  description = "VS Code Remote SSH config snippet"
  value = var.create_public_ip ? (
    <<-EOT
    Host coding-agent
        HostName ${azurerm_public_ip.main[0].ip_address}
        User ${var.admin_username}
        IdentityFile ~/.ssh/id_rsa
        StrictHostKeyChecking no
    EOT
  ) : (
    <<-EOT
    Host coding-agent
        HostName ${azurerm_network_interface.main.private_ip_addresses[0]}
        User ${var.admin_username}
        IdentityFile ~/.ssh/id_rsa
        StrictHostKeyChecking no
    EOT
  )
}

output "vm_principal_id" {
  description = "Managed Identity Principal ID (for granting Azure resource access)"
  value       = azurerm_linux_virtual_machine.agent.identity[0].principal_id
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.main.location
}

output "vnet_id" {
  description = "Virtual Network ID (for VPN peering)"
  value       = azurerm_virtual_network.main.id
}

output "subnet_id" {
  description = "Subnet ID (for Bastion or peered networks)"
  value       = azurerm_subnet.main.id
}
