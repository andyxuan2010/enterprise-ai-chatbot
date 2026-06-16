subscription_id = "bb759f2e-505c-4524-9e64-8bfae839b384" # default: ""
location        = "canadacentral"                        # default: "eastus"
workload        = "aichatbot"                            # default: "chatbot"
environment     = "sandbox"                              # default: "dev"
features = {
  enable_app_service_stack               = true
  enable_app_registration_for_appservice = true
  enable_openai                          = true
  enable_azure_ai_service                = true
  enable_azure_ai_search                 = true
  create_azure_search_query_key          = true
}
resource_group_name       = ""   # default: use landingzone_resource_group_name
app_service_plan_name     = ""   # default: generated as "asp-${workload}-${environment}"
app_service_plan_sku_name = "B1" # minimum SKU that supports App Service private endpoint
app_service_name          = ""   # default: generated as "web-${workload}-${environment}"
# Set APP_SERVICE_CUSTOM_HOSTNAME in Azure DevOps, or TF_VAR_app_service_custom_hostname in Bash/PowerShell, to bind a custom domain.
# Create CNAME <custom-hostname> -> web-aichatbot-sandbox.azurewebsites.net before enabling the binding.
app_registration_display_name             = ""     # default: generated as "appreg-${workload}-${environment}"
app_service_public_network_access_enabled = true   # keep public deployment access for hosted Azure Pipelines
app_service_python_version                = "3.12" # default: "3.12"
app_service_enable_auth                   = false  # default: false

# these 2 settings for ado git source deployment
# deployment_method controls these two settings for each app:
# - deployment_center / zip_deploy_with_build => true
# - run_from_package => false
app_service_app_settings = {
  SCM_DO_BUILD_DURING_DEPLOYMENT = true
  ENABLE_ORYX_BUILD              = true
  # AZURE_OPENAI_CHAT_DEPLOYMENT   = "gpt-4o"
  # AZURE_OPENAI_EMBED_DEPLOYMENT  = "text-embedding-ada-002"
  # AZURE_SEARCH_INDEX             = "index"
}


#app_service_ip_restriction_default_action = "Deny"                                 # default: "Deny"
enable_app_service_stack                  = true                   # default: true
landingzone_resource_group_name           = "rg-platform-sbx"      # default: ""
landingzone_ai_resource_group_name        = "rg-platform-sbx"      # default: ""
landingzone_storage_account_name          = "stplatformccsbx"      # default: ""
landingzone_key_vault_name                = "kvplatformccsbx"      # default: ""
landingzone_openai_name                   = "oai-platform-cc-sbx"  # default: ""
landingzone_azure_ai_service_name         = "ai-platform-cc-sbx"   # default: ""
landingzone_azure_ai_search_name          = "srch-platform-cc-sbx" # default: ""
landingzone_azure_ai_search_enabled       = true                   # default: true
landingzone_log_analytics_name            = "law-platform-cc-sbx"  # default: ""
app_service_ip_restrictions               = []
app_service_ip_restriction_default_action = "Allow"
app_service_enable_private_endpoint       = false
#app_service_scm_basic_auth_publishing_credentials_enabled = true                                   # required for az webapp deploy zip/Kudu deployments
#app_service_scm_use_main_ip_restriction                   = true                                   # reuse main site access rules for Kudu/SCM
app_service_private_endpoint_subnet_name                 = "snet-private-endpoints"
app_service_private_endpoint_vnet_name                   = "vnet-spoke-platform-sbx"
app_service_private_endpoint_network_resource_group_name = "rg-platform-sbx"
app_service_private_dns_zone_name                        = "privatelink.azurewebsites.net"
app_service_private_dns_zone_resource_group_name         = "rg-platform-sbx"
# app_service_ip_restrictions = [
#   {
#     name       = "Allow-HTTPS-107-171-157-217"
#     priority   = 100
#     action     = "Allow"
#     ip_address = "107.171.157.217/32"
#   }
# ]

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
