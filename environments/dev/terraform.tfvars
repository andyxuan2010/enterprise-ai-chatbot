subscription_id                 = "1ec5edd4-5654-4246-8027-b29ef63b3393"
location                        = "eastus"
workload                        = "aidoc"
environment                     = "dev"
resource_group_name             = ""
landingzone_resource_group_name = "rg-platform-dev"
#iac_resource_group_name           = "rg-ccoe-iac-cc-dev"
landingzone_storage_account_name = "stplatformeusdev"
#iac_storage_account_name          = "stccoeiacccdev"
landingzone_key_vault_name = "kvplatformeusdev"
#iac_key_vault_name                = "kv-ccoe-cc-dev"
landingzone_log_analytics_name    = "law-platform-eus-dev"
landingzone_openai_name           = "oai-platform-eus-dev"
landingzone_azure_ai_service_name = "ai-platform-eus-dev"

function_app_name = "func-aidoc-dev"
logic_app_name    = "logic-aidoc-dev"
sql_server_name   = "sql-aidoc-dev"
sql_database_name = "sqldb-aidoc-dev"

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
#sql_admin_credentials_key_vault_id = "/subscriptions/1ec5edd4-5654-4246-8027-b29ef63b3393/resourceGroups/rg-platform-dev/providers/Microsoft.KeyVault/vaults/kvplatformeusdev"


sql_ad_admin_login_name = "BA-G-Azure-Owner-F"
sql_ad_admin_object_id  = "db86733f-51f7-46ce-a989-6bf17afe0f32"

rg_tags = {
  "Application Name"                  = "CCOE INFRA IAC"
  "Application Owner"                 = "CCOE"
  "AppSupport Team"                   = "CCOE"
  "Approval Group"                    = "CCOE"
  "Business Owner"                    = "CCOE"
  "Environment"                       = "Dev"
  "Infra Availability Classification" = "Bronze"
  "InfraSupport Team"                 = "CCOE"
  "Maintenance Window"                = "CCOE"
  "Project Name"                      = "CCOE INFRA IAC"
  "Project Number"                    = "N/A"
  "RPO-RTO"                           = "48H/24H"
  "Run Cost(Approved Run Budget)-USD" = "100"
}
