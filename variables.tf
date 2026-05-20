variable "subscription_id" {
  description = "Optional Azure subscription ID for the default azurerm provider. Leave empty to use ARM_SUBSCRIPTION_ID from the execution environment."
  type        = string
  default     = ""
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
  description = "Azure region for workload resources."
  type        = string
  default     = "eastus"
}

variable "workload" {
  description = "Short workload identifier used in names and tags."
  type        = string
  default     = "aidoc"
}

variable "environment" {
  description = "Environment name for this deployment."
  type        = string
  default     = "dev"
}

variable "resource_group_name" {
  description = "Optional workload resource group name. Leave empty to deploy into the landingzone resource group."
  type        = string
  default     = ""
}

variable "landingzone_ai_resource_group_name" {
  description = "Deprecated fallback resource group name for landingzone shared resources. Prefer landingzone_resource_group_name."
  type        = string
  default     = ""
}

variable "landingzone_resource_group_name" {
  description = "Resource group in the sibling landingzone repo that holds shared resources used by this project."
  type        = string
  default     = ""
}
variable "iac_resource_group_name" {
  description = "Resource group in the sibling landingzone repo that holds shared resources keyvault/storage account used by this project."
  type        = string
  default     = ""
}
variable "landingzone_storage_account_name" {
  description = "Existing landingzone Storage Account name used by the Function App runtime."
  type        = string
  default     = ""
}
variable "iac_storage_account_name" {
  description = "Existing iac Storage Account name used by the Function App runtime."
  type        = string
  default     = ""
}
variable "landingzone_key_vault_name" {
  description = "Existing landingzone Key Vault name used for SQL admin credential secrets."
  type        = string
  default     = ""
}
variable "iac_key_vault_name" {
  description = "Existing iac Key Vault name used for SQL admin credential secrets."
  type        = string
  default     = ""
}
variable "landingzone_log_analytics_name" {
  description = "Existing Log Analytics workspace name from the landingzone."
  type        = string
  default     = ""
}

variable "landingzone_openai_name" {
  description = "Existing Azure OpenAI account name from the landingzone."
  type        = string
  default     = ""
}

variable "landingzone_openai_enabled" {
  description = "Whether the shared landingzone Azure OpenAI account should be looked up and used."
  type        = bool
  default     = true
}

variable "landingzone_azure_ai_service_name" {
  description = "Existing landingzone Azure AI Service account name used for Document Intelligence endpoint access."
  type        = string
  default     = ""
}

variable "landingzone_azure_ai_service_enabled" {
  description = "Whether the shared landingzone Azure AI Service account should be looked up and used."
  type        = bool
  default     = true
}

variable "create_azure_openai_chat_deployment" {
  description = "Whether to create a workload-specific chat deployment on the landingzone Azure OpenAI account."
  type        = bool
  default     = true
}

variable "azure_openai_chat_deployment_name" {
  description = "Azure OpenAI chat deployment name exposed to the Function App."
  type        = string
  default     = ""
}

variable "azure_openai_chat_model_name" {
  description = "Azure OpenAI chat model name for extraction post-processing."
  type        = string
  default     = "gpt-5-chat"
}

variable "azure_openai_chat_model_version" {
  description = "Azure OpenAI chat model version for extraction post-processing."
  type        = string
  default     = "2025-08-07"
}

variable "azure_openai_chat_deployment_sku_name" {
  description = "SKU name for the Azure OpenAI chat deployment."
  type        = string
  default     = "GlobalStandard"
}

variable "azure_openai_chat_deployment_capacity" {
  description = "Capacity for the Azure OpenAI chat deployment."
  type        = number
  default     = 10
}

variable "enable_function_app" {
  description = "Whether to provision the Function App plan and Function App through the template modules."
  type        = bool
  default     = true
}

variable "function_plan_name" {
  description = "Optional override for the Azure Functions hosting plan name."
  type        = string
  default     = ""
}

variable "function_plan_sku_name" {
  description = "SKU name for the Linux Azure Functions plan. Use Y1 for consumption."
  type        = string
  default     = "Y1"
}

variable "function_plan_enable_diagnostics" {
  description = "Whether to enable diagnostics for the Function App service plan."
  type        = bool
  default     = false
}

variable "function_app_name" {
  description = "Optional override for the Function App name. This must be globally unique in Azure."
  type        = string
  default     = ""
}

variable "function_python_version" {
  description = "Python runtime version for the Linux Function App."
  type        = string
  default     = "3.12"
}

variable "function_public_network_access_enabled" {
  description = "Whether public network access is enabled for the Function App."
  type        = bool
  default     = true
}

variable "function_enable_diagnostics" {
  description = "Whether to enable diagnostics for the Function App."
  type        = bool
  default     = false
}

variable "function_app_settings" {
  description = "Additional app settings for the Function App."
  type        = map(string)
  default     = {}
}

variable "logic_app_name" {
  description = "Optional override for the Logic App workflow name."
  type        = string
  default     = ""
}

variable "sql_server_name" {
  description = "Optional override for the Azure SQL logical server name. This must be globally unique in Azure."
  type        = string
  default     = ""
}

variable "sql_database_name" {
  description = "Optional override for the Azure SQL database name."
  type        = string
  default     = ""
}

variable "sql_database_sku_name" {
  description = "SKU name for the Azure SQL database."
  type        = string
  default     = "Basic"
}

variable "sql_database_max_size_gb" {
  description = "Maximum size in GB for the Azure SQL database."
  type        = number
  default     = 2
}

variable "sql_backup_storage_redundancy" {
  description = "Backup storage redundancy for Azure SQL Database. Valid values are Local, Zone, or Geo."
  type        = string
  default     = "Local"
}

variable "sql_public_network_access_enabled" {
  description = "Whether public network access is enabled for the Azure SQL server."
  type        = bool
  default     = true
}

variable "sql_firewall_rules" {
  description = "Optional SQL Server firewall rules keyed by rule name."
  type = map(object({
    start_ip_address = string
    end_ip_address   = string
  }))
  default = {
    AllowAzureServices = {
      start_ip_address = "0.0.0.0"
      end_ip_address   = "0.0.0.0"
    }
  }
}

variable "sql_administrator_login" {
  description = "Optional SQL administrator login. Leave empty to read the template module default secret from Key Vault."
  type        = string
  default     = null
  sensitive   = true
}

variable "sql_administrator_password" {
  description = "Optional SQL administrator password. Leave empty to read the template module default secret from Key Vault."
  type        = string
  default     = null
  sensitive   = true
}

variable "sql_admin_credentials_key_vault_id" {
  description = "Optional Key Vault resource ID for SQL admin credentials. Defaults to the landingzone Key Vault."
  type        = string
  default     = ""
}

variable "sql_admin_username_secret_name" {
  description = "Key Vault secret name containing the SQL admin username."
  type        = string
  default     = "sqladmin-username"
}

variable "sql_admin_password_secret_name" {
  description = "Key Vault secret name containing the SQL admin password."
  type        = string
  default     = "sqladminuser-password"
}

variable "sql_ad_admin_login_name" {
  description = "Microsoft Entra admin login display name for Azure SQL."
  type        = string
  default     = "sql-admin-group"
}

variable "sql_ad_admin_object_id" {
  description = "Microsoft Entra admin object ID for Azure SQL."
  type        = string
}

variable "sql_enable_private_endpoint" {
  description = "Whether to enable a private endpoint for the Azure SQL server."
  type        = bool
  default     = false
}

variable "sql_private_endpoint_subnet_id" {
  description = "Subnet ID for the Azure SQL private endpoint."
  type        = string
  default     = ""
}

variable "sql_private_dns_zone_ids" {
  description = "Private DNS zone IDs to associate with the Azure SQL private endpoint."
  type        = list(string)
  default     = []
}

variable "sql_enable_diagnostics" {
  description = "Whether to enable diagnostics for the Azure SQL database."
  type        = bool
  default     = false
}

variable "app_admin_group" {
  description = "Microsoft Entra group display names or object IDs that should receive Contributor access through template modules."
  type        = list(string)
  default     = []
}

variable "app_user_group" {
  description = "Microsoft Entra group display names or object IDs that should receive Reader access through template modules."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Optional extra tags applied on top of the landingzone-style governance tags."
  type        = map(string)
  default     = {}
}
