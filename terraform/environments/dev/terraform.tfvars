subscription_id = "1ec5edd4-5654-4246-8027-b29ef63b3393" # default: ""
location        = "canadacentral"                        # default: "eastus"
workload        = "aichatbot"                            # default: "chatbot"
environment     = "dev"                                  # default: "dev"
features = {
  enable_app_service_stack               = false
  enable_app_registration_for_appservice = true
  enable_openai                          = true
  enable_azure_ai_service                = true
  enable_azure_ai_search                 = true
  create_azure_search_query_key          = true
}
resource_group_name   = "" # default: use landingzone_resource_group_name
app_service_plan_name = "" # default: generated as "asp-${workload}-${environment}"
app_service_name      = "" # default: generated as "web-${workload}-${environment}"
# App Service stack is disabled in dev; custom hostname variables are ignored.
app_registration_display_name             = ""                     # default: generated as "appreg-${workload}-${environment}"
app_service_python_version                = "3.12"                 # default: "3.12"
app_service_enable_auth                   = false                  # default: false
app_service_ip_restriction_default_action = "Deny"                 # default: "Deny"
enable_app_service_stack                  = false                  # default: true
landingzone_resource_group_name           = "rg-platform-dev"      # default: ""
landingzone_ai_resource_group_name        = "rg-platform-dev"      # default: ""
landingzone_storage_account_name          = "stplatformccdev"      # default: ""
landingzone_key_vault_name                = "kvplatformccdev"      # default: ""
landingzone_openai_name                   = "oai-platform-cc-dev"  # default: ""
landingzone_azure_ai_service_name         = "ai-platform-cc-dev"   # default: ""
landingzone_azure_ai_search_name          = "srch-platform-cc-dev" # default: ""
landingzone_azure_ai_search_enabled       = true                   # default: true
landingzone_log_analytics_name            = "law-platform-cc-dev"  # default: ""

app_service_ip_restrictions = [
  {
    name       = "Allow-HTTPS-107-171-157-217"
    priority   = 100
    action     = "Allow"
    ip_address = "107.171.157.217/32"
  }
]

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
