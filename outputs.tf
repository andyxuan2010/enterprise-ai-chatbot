output "resource_group_name" {
  description = "Resource group used for workload resources."
  value       = local.resource_group_name
}

output "document_intelligence_account_name" {
  description = "Landingzone Azure AI Service account used for Document Intelligence."
  value       = local.landingzone_azure_ai_service_lookup_enabled && length(data.azurerm_cognitive_account.azure_ai_service) > 0 ? data.azurerm_cognitive_account.azure_ai_service[0].name : null
}

output "document_intelligence_endpoint" {
  description = "Endpoint for the landingzone Azure AI Service used by Document Intelligence."
  value       = local.document_intelligence_endpoint
}

output "azure_openai_account_name" {
  description = "Landingzone Azure OpenAI account used by this workload."
  value       = local.landingzone_openai_lookup_enabled && length(data.azurerm_cognitive_account.openai) > 0 ? data.azurerm_cognitive_account.openai[0].name : null
}

output "azure_openai_endpoint" {
  description = "Endpoint for the landingzone Azure OpenAI account."
  value       = local.azure_openai_endpoint
}

output "azure_openai_chat_deployment_name" {
  description = "Azure OpenAI chat deployment name exposed to the Function App."
  value       = local.openai_chat_app_setting_name
}

output "function_app_service_plan_id" {
  description = "Resource ID of the Function App service plan."
  value       = var.enable_function_app ? module.function_app_service_plan[0].id : null
}

output "function_app_name" {
  description = "Name of the Azure Function App."
  value       = var.enable_function_app ? module.functionapp[0].name : null
}

output "function_app_default_hostname" {
  description = "Default hostname of the Azure Function App."
  value       = var.enable_function_app ? module.functionapp[0].default_hostname : null
}

output "function_app_identity_principal_id" {
  description = "Principal ID of the system-assigned managed identity on the Function App."
  value       = var.enable_function_app ? module.functionapp[0].identity_principal_id : null
}

output "logic_app_name" {
  description = "Name of the Logic App workflow."
  value       = azurerm_logic_app_workflow.document_processing.name
}

output "logic_app_identity_principal_id" {
  description = "Principal ID of the system-assigned managed identity on the Logic App workflow."
  value       = azurerm_logic_app_workflow.document_processing.identity[0].principal_id
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the Azure SQL server."
  value       = module.sqldb.server_fqdn
}

output "sql_database_name" {
  description = "Name of the Azure SQL database."
  value       = module.sqldb.database_name
}
