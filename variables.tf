variable "subscription_id" {
  description = "Optional Azure subscription ID for the default azurerm provider. Leave empty to use ARM_SUBSCRIPTION_ID from the execution environment."
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Shared common tags baseline cloned from the landingzone repo."
  type        = map(any)
  default = {
    "Application Name"                  = "CCOE INFRA IAC"
    "Application Owner"                 = "CCOE"
    "AppSupport Team"                   = "CCOE"
    "Approval Group"                    = "CCOE"
    "Business Owner"                    = "CCOE"
    "Infra Availability Classification" = "Bronze"
    "InfraSupport Team"                 = "CCOE"
    "Maintenance Window"                = "CCOE"
    "Project Name"                      = "CCOE INFRA IAC"
    "Project Number"                    = "N/A"
    "RPO-RTO"                           = "48H/24H"
    "Run Cost(Approved Run Budget)-USD" = "100"
  }
}

variable "rg_tags" {
  description = "Resource-group style governance tags cloned from the landingzone repo."
  type        = map(any)
  default = {
    "Application Name"                  = "CCOE INFRA IAC"
    "Application Owner"                 = "CCOE"
    "AppSupport Team"                   = "CCOE"
    "Approval Group"                    = "CCOE"
    "Business Owner"                    = "CCOE"
    "Environment"                       = "Sandbox"
    "Infra Availability Classification" = "Bronze"
    "InfraSupport Team"                 = "CCOE"
    "Maintenance Window"                = "CCOE"
    "Project Name"                      = "CCOE INFRA IAC"
    "Project Number"                    = "N/A"
    "RPO-RTO"                           = "48H/24H"
    "Run Cost(Approved Run Budget)-USD" = "100"
  }
}

variable "location" {
  description = "Azure region for this Terraform project."
  type        = string
  default     = "eastus"
}

variable "workload" {
  description = "Short workload identifier used in names and tags."
  type        = string
  default     = "chatbot"
}

variable "environment" {
  description = "Environment name for this deployment."
  type        = string
  default     = "dev"
}

variable "resource_group_name" {
  description = "Optional override for the application resource group."
  type        = string
  default     = ""
}

variable "app_service_plan_name" {
  description = "Optional override for the App Service Plan name."
  type        = string
  default     = ""
}

variable "app_service_name" {
  description = "Optional override for the App Service name. This must be globally unique in Azure."
  type        = string
  default     = ""
}

variable "app_registration_display_name" {
  description = "Optional override for the Microsoft Entra app registration display name."
  type        = string
  default     = ""
}

variable "app_service_plan_sku_name" {
  description = "SKU name for the Linux App Service Plan."
  type        = string
  default     = "B1"
}

variable "app_service_python_version" {
  description = "Python runtime version for the Linux App Service."
  type        = string
  default     = "3.12"
}

variable "app_registration_create_client_secret" {
  description = "Whether to create a client secret for the Entra app registration."
  type        = bool
  default     = false
}

variable "app_service_enable_auth" {
  description = "Whether to wire the Entra app registration into the App Service auth configuration."
  type        = bool
  default     = false
}

variable "app_service_scm_basic_auth_publishing_credentials_enabled" {
  description = "Whether SCM/Kudu basic auth publishing credentials are enabled for zip deployments."
  type        = bool
  default     = false
}

variable "app_service_ip_restrictions" {
  description = "Site access restrictions for the App Service public endpoint."

  type = list(object({
    action      = optional(string, "Allow")
    ip_address  = optional(string)
    name        = string
    priority    = number
    service_tag = optional(string)

    headers = optional(object({
      x_forwarded_for   = optional(list(string))
      x_forwarded_host  = optional(list(string))
      x_azure_fdid      = optional(list(string))
      x_fd_health_probe = optional(list(string))
    }))
  }))

  default = []
}

variable "app_service_ip_restriction_default_action" {
  description = "Default action for App Service site access traffic that does not match an IP restriction rule."
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.app_service_ip_restriction_default_action)
    error_message = "app_service_ip_restriction_default_action must be either Allow or Deny."
  }
}

variable "enable_app_service_stack" {
  description = "Whether to provision the App Service Plan, App Service, and supporting app registration."
  type        = bool
  default     = true
}

variable "app_service_app_settings" {
  description = "Additional app settings for the Python App Service."
  type        = map(string)
  default     = {}
}

variable "landingzone_ai_resource_group_name" {
  description = "Deprecated fallback resource group name for landingzone shared resources. Prefer landingzone_resource_group_name."
  type        = string
  default     = ""
}

variable "landingzone_resource_group_name" {
  description = "Resource group in the sibling landingzone repo that holds the shared resources used by this project."
  type        = string
  default     = ""
}

variable "landingzone_openai_name" {
  description = "Existing Azure OpenAI account name from the landingzone."
  type        = string
  default     = ""
}

variable "landingzone_openai_enabled" {
  description = "Whether the shared landingzone Azure OpenAI account should be looked up and wired into this app."
  type        = bool
  default     = true
}

variable "landingzone_azure_ai_service_name" {
  description = "Existing Azure AI Service account name from the landingzone."
  type        = string
  default     = ""
}

variable "landingzone_azure_ai_service_enabled" {
  description = "Whether the shared landingzone Azure AI Service account should be looked up and wired into this app."
  type        = bool
  default     = true
}

variable "landingzone_azure_ai_search_name" {
  description = "Existing Azure AI Search service name from the landingzone."
  type        = string
  default     = ""
}

variable "landingzone_azure_ai_search_enabled" {
  description = "Whether the shared landingzone Azure AI Search service should be looked up and wired into this app."
  type        = bool
  default     = true
}

variable "landingzone_log_analytics_name" {
  description = "Existing Log Analytics workspace name from the landingzone."
  type        = string
  default     = ""
}

variable "landingzone_key_vault_name" {
  description = "Existing Key Vault name from the landingzone."
  type        = string
  default     = ""
}

variable "landingzone_storage_account_name" {
  description = "Existing Storage Account name from the landingzone."
  type        = string
  default     = ""
}

variable "azure_openai_chat_deployment" {
  description = "Azure OpenAI chat deployment name exposed to the app."
  type        = string
  default     = ""
}

variable "azure_openai_embed_deployment" {
  description = "Azure OpenAI embedding deployment name exposed to the app."
  type        = string
  default     = ""
}

variable "azure_search_index" {
  description = "Azure AI Search index name exposed to the app."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Optional extra tags applied on top of the landingzone-style governance tags."
  type        = map(string)
  default     = {}
}
