output "resource_group_name" {
  description = "Resource group created for the application resources."
  value       = azurerm_resource_group.this.name
}

output "app_service_plan_id" {
  description = "Resource ID of the App Service Plan."
  value       = var.enable_app_service_stack ? module.app_service_plan[0].id : null
}

output "app_service_name" {
  description = "Name of the Linux App Service."
  value       = var.enable_app_service_stack ? module.app_service[0].app_name : null
}

output "app_service_default_hostname" {
  description = "Default hostname of the Linux App Service."
  value       = var.enable_app_service_stack ? module.app_service[0].default_hostname : null
}

output "app_service_url" {
  description = "HTTPS URL of the Linux App Service."
  value       = var.enable_app_service_stack ? "https://${module.app_service[0].default_hostname}" : null
}

output "app_service_identity_principal_id" {
  description = "Principal ID of the system-assigned managed identity on the App Service."
  value       = var.enable_app_service_stack ? module.app_service[0].identity_principal_id : null
}

output "app_registration_application_id" {
  description = "Application (client) ID of the Entra app registration."
  value       = var.enable_app_service_stack ? module.app_registration_appservice[0].application_id : null
}

output "azure_openai_endpoint" {
  description = "Resolved Azure OpenAI endpoint from the existing landingzone service."
  value       = local.azure_openai_endpoint
}

output "azure_ai_service_endpoint" {
  description = "Resolved Azure AI Service endpoint from the existing landingzone service."
  value       = local.azure_ai_service_endpoint
}

output "azure_ai_search_endpoint" {
  description = "Resolved Azure AI Search endpoint from the existing landingzone service."
  value       = local.azure_ai_search_endpoint
}

output "landingzone_log_analytics_workspace_id" {
  description = "Resolved Log Analytics workspace ID from the existing landingzone workspace."
  value       = local.log_analytics_workspace_id
}

output "landingzone_resource_group_name" {
  description = "Resolved shared landingzone resource group name."
  value       = data.azurerm_resource_group.landingzone.name
}

output "landingzone_key_vault_id" {
  description = "Resolved shared landingzone Key Vault ID."
  value       = data.azurerm_key_vault.landingzone.id
}

output "landingzone_storage_account_id" {
  description = "Resolved shared landingzone Storage Account ID."
  value       = data.azurerm_storage_account.landingzone.id
}
