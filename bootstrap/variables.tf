variable "location" {
  description = "Azure region for the Terraform state backend"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Resource group for the Terraform state backend"
  type        = string
  default     = "rg-terraform-state"
}

variable "storage_account_name" {
  description = "Globally unique storage account name (auto-generated if empty)"
  type        = string
  default     = ""
}

variable "container_name" {
  description = "Blob container name for Terraform state"
  type        = string
  default     = "tfstate"
}
