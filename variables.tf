variable "subscription_id" {
  description = "Azure subscription ID used by the provider."
  type        = string
}

variable "location" {
  description = "Azure region for the deployment."
  type        = string
  default     = "East US"
}

variable "name_prefix" {
  description = "Short resource naming prefix; use lowercase letters and numbers."
  type        = string
  default     = "secure3tier"
  validation {
    condition     = can(regex("^[a-z0-9]{3,12}$", var.name_prefix))
    error_message = "name_prefix must be 3-12 lowercase letters/numbers."
  }
}

variable "admin_username" {
  description = "Linux admin username for demonstration workload VMs."
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "SSH public key; private key must never be stored in Terraform or GitHub."
  type        = string
  sensitive   = true
}

variable "sql_admin_username" {
  description = "SQL administrator username. Prefer Entra-only authentication in production."
  type        = string
  default     = "sqlbootstrapadmin"
}

variable "sql_admin_password" {
  description = "Strong SQL administrator password. Supply through a secure secret mechanism."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    environment = "production"
    managed_by  = "terraform"
    workload    = "secure-3tier"
  }
}

variable "tls_certificate_pfx_base64" {
  description = "Base64-encoded PFX certificate for Application Gateway HTTPS listener. Provide from GitHub secret."
  type        = string
  sensitive   = true
}

variable "tls_certificate_password" {
  description = "Password protecting the Application Gateway PFX certificate."
  type        = string
  sensitive   = true
}
