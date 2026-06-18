variable "location" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-coding-agent"
}

variable "vm_size" {
  description = "Azure VM SKU. B2ms = 2 vCPU, 8GB RAM (~$46/mo pay-as-you-go)"
  type        = string
  default     = "Standard_B2ms"
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "vm-coding-agent"
}

variable "admin_username" {
  description = "Local admin username on the VM"
  type        = string
  default     = "agent"
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key (~/.ssh/id_rsa.pub or similar)"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_allowed_ip" {
  description = "IP address or CIDR allowed to SSH into the VM. Set to your VPN egress IP or '0.0.0.0/0' with caution"
  type        = string
  default     = "0.0.0.0/0"
}

variable "create_public_ip" {
  description = "Attach a public IP to the VM. Set false if accessing via corporate VPN / Azure Bastion (recommended for Volvo corporate network)"
  type        = bool
  default     = false
}

variable "disk_size_gb" {
  description = "OS disk size in GB. 64GB+ recommended for Docker images + monorepos"
  type        = number
  default     = 64
}

variable "disk_type" {
  description = "OS disk SKU. Premium_LRS for better IO, StandardSSD_LRS for cost saving"
  type        = string
  default     = "Premium_LRS"
}

variable "ubuntu_version" {
  description = "Ubuntu LTS version. 22_04-lts or 24_04-lts"
  type        = string
  default     = "22_04-lts"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    project     = "coding-agent-vm"
    managed_by  = "terraform"
    environment = "development"
  }
}

variable "docker_disk_size_gb" {
  description = "Additional data disk size in GB for Docker storage. 0 to skip"
  type        = number
  default     = 32
}

variable "enable_azure_monitor" {
  description = "Enable Azure Monitor agent for VM insights"
  type        = bool
  default     = false
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefix" {
  description = "Address prefix for the VM subnet"
  type        = string
  default     = "10.0.1.0/24"
}
