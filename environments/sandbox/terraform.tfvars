subscription_id                   = "bb759f2e-505c-4524-9e64-8bfae839b384"
location                          = "canadacentral"
workload                          = "aidoc"
environment                       = "sandbox"
resource_group_name               = ""
landingzone_resource_group_name   = "rg-platform-sbx"
iac_resource_group_name           = "rg-ccoe-iac-cc-sbx"
landingzone_storage_account_name  = "stccoeiacccsbx"
iac_storage_account_name          = "stccoeiacccsbx"
landingzone_key_vault_name        = "kv-ccoe-cc-sbx"
iac_key_vault_name                = "kv-ccoe-cc-sbx"
landingzone_log_analytics_name    = "law-platform-cc-sbx"
landingzone_openai_name           = "oai-platform-cc-sbx"
landingzone_azure_ai_service_name = "ai-platform-cc-sbx"

function_app_name = "func-aidoc-sandbox"
logic_app_name    = "logic-aidoc-sandbox"
sql_server_name   = "sql-aidoc-sandbox"
sql_database_name = "sqldb-aidoc-sandbox"

create_azure_openai_chat_deployment = true
azure_openai_chat_deployment_name   = "extraction-chat"
# azure_openai_chat_model_name        = "gpt-4o-mini"
# azure_openai_chat_model_version     = "2024-07-18"

function_python_version                = "3.12"
function_plan_sku_name                 = "B1"
function_public_network_access_enabled = true

sql_database_sku_name             = "Basic"
sql_public_network_access_enabled = true
sql_database_max_size_gb          = 2
sql_backup_storage_redundancy     = "Local"

sql_firewall_rules = {
  my_ip = {
    start_ip_address = "107.171.157.217"
    end_ip_address   = "107.171.157.217"
  }
}

sql_administrator_login    = null
sql_administrator_password = null
# sql_admin_username_secret_name     = "sqladmin-username"
# sql_admin_password_secret_name     = "sqladminuser-password"
sql_admin_credentials_key_vault_id = "/subscriptions/bb759f2e-505c-4524-9e64-8bfae839b384/resourceGroups/rg-ccoe-iac-cc-sbx/providers/Microsoft.KeyVault/vaults/kv-ccoe-cc-sbx"

sql_ad_admin_login_name = "BA-G-Azure-Owner-F"
sql_ad_admin_object_id  = "534422f9-5a5e-4ebe-86f6-714fb9d17fe3"

rg_tags = {
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
