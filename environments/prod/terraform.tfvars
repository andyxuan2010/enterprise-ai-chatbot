subscription_id                      = "00000000-0000-0000-0000-000000000000"
location                             = "eastus"
workload                             = "aidoc"
environment                          = "prod"
resource_group_name                  = "rg-enterprise-ai-doc-prod"
landingzone_resource_group_name      = "TODO-rg-platform-prod"
landingzone_storage_account_name     = "TODO-storage-account-name"
landingzone_key_vault_name           = "TODO-key-vault-name"
landingzone_log_analytics_name       = "TODO-log-analytics-name"
landingzone_openai_name              = "TODO-openai-name"
landingzone_openai_enabled           = false
landingzone_azure_ai_service_name    = "TODO-azure-ai-service-name"
landingzone_azure_ai_service_enabled = false

function_app_name = "func-aidoc-prod"
logic_app_name    = "logic-aidoc-prod"
sql_server_name   = "sql-aidoc-prod"
sql_database_name = "sqldb-aidoc-prod"

create_azure_openai_chat_deployment = false
azure_openai_chat_deployment_name   = "extraction-chat"
# azure_openai_chat_model_name        = "gpt-4o-mini"
# azure_openai_chat_model_version     = "2024-07-18"

function_python_version                = "3.12"
function_public_network_access_enabled = true
sql_database_sku_name                  = "Basic"
sql_public_network_access_enabled      = true
sql_ad_admin_login_name                = "sql-admin-group"
sql_ad_admin_object_id                 = "00000000-0000-0000-0000-000000000000"

rg_tags = {
  "Application Name"                  = "CCOE INFRA IAC"
  "Application Owner"                 = "CCOE"
  "AppSupport Team"                   = "CCOE"
  "Approval Group"                    = "CCOE"
  "Business Owner"                    = "CCOE"
  "Environment"                       = "Prod"
  "Infra Availability Classification" = "Bronze"
  "InfraSupport Team"                 = "CCOE"
  "Maintenance Window"                = "CCOE"
  "Project Name"                      = "CCOE INFRA IAC"
  "Project Number"                    = "N/A"
  "RPO-RTO"                           = "48H/24H"
  "Run Cost(Approved Run Budget)-USD" = "100"
}
