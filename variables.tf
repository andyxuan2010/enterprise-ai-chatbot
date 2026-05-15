variable "subscription_id" {
  description = "Optional Azure subscription ID for the default azurerm provider. Leave empty to use ARM_SUBSCRIPTION_ID from the execution environment."
  type        = string
  default     = ""
}

variable "location" {
  description = "Azure region for this Terraform project."
  type        = string
  default     = "eastus"
}

variable "workload" {
  description = "Short workload identifier used in names and tags."
  type        = string
  default     = "enterprise-ai-chatbot"
}

variable "environment" {
  description = "Environment name for this deployment."
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Optional tags applied to resources created by this project."
  type        = map(string)
  default     = {}
}
