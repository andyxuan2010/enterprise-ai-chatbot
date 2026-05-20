# -------------------------------------------------------------------
# Naming and Shared Values
# -------------------------------------------------------------------

locals {
  workload_slug         = lower(replace(var.workload, "_", "-"))
  effective_environment = trimspace(var.environment) != "" ? lower(var.environment) : "dev"
  module_app_env        = local.effective_environment == "sandbox" ? "sbx" : local.effective_environment
  landingzone_resource_group_name = (
    trimspace(var.landingzone_resource_group_name) != ""
    ? var.landingzone_resource_group_name
    : var.landingzone_ai_resource_group_name
  )
  iac_resource_group_name = (
    trimspace(var.iac_resource_group_name) != ""
    ? var.iac_resource_group_name
    : local.landingzone_resource_group_name
  )
  storage_account_name = (
    trimspace(var.iac_storage_account_name) != ""
    ? var.iac_storage_account_name
    : var.landingzone_storage_account_name
  )
  key_vault_name = (
    trimspace(var.iac_key_vault_name) != ""
    ? var.iac_key_vault_name
    : var.landingzone_key_vault_name
  )
  create_resource_group   = trimspace(var.resource_group_name) != ""
  resource_group_name     = local.create_resource_group ? var.resource_group_name : data.azurerm_resource_group.landingzone.name
  resource_group_location = local.create_resource_group ? var.location : data.azurerm_resource_group.landingzone.location

  landingzone_openai_lookup_enabled           = var.landingzone_openai_enabled && trimspace(var.landingzone_openai_name) != ""
  landingzone_azure_ai_service_lookup_enabled = var.landingzone_azure_ai_service_enabled && trimspace(var.landingzone_azure_ai_service_name) != ""

  azure_openai_endpoint          = local.landingzone_openai_lookup_enabled && length(data.azurerm_cognitive_account.openai) > 0 ? try(data.azurerm_cognitive_account.openai[0].endpoint, "https://${data.azurerm_cognitive_account.openai[0].name}.openai.azure.com/") : ""
  document_intelligence_endpoint = local.landingzone_azure_ai_service_lookup_enabled && length(data.azurerm_cognitive_account.azure_ai_service) > 0 ? try(data.azurerm_cognitive_account.azure_ai_service[0].endpoint, "https://${data.azurerm_cognitive_account.azure_ai_service[0].name}.cognitiveservices.azure.com/") : ""
  openai_chat_deployment_name    = trimspace(var.azure_openai_chat_deployment_name) != "" ? var.azure_openai_chat_deployment_name : "extraction-chat"
  openai_chat_app_setting_name   = length(azurerm_cognitive_deployment.extraction_chat) > 0 ? azurerm_cognitive_deployment.extraction_chat[0].name : local.openai_chat_deployment_name
  function_plan_name             = trimspace(var.function_plan_name) != "" ? var.function_plan_name : "asp-${local.workload_slug}-func-${local.effective_environment}"
  function_app_name              = trimspace(var.function_app_name) != "" ? var.function_app_name : "func-${local.workload_slug}-${local.effective_environment}"
  logic_app_name                 = trimspace(var.logic_app_name) != "" ? var.logic_app_name : "logic-${local.workload_slug}-${local.effective_environment}"
  sql_server_name                = trimspace(var.sql_server_name) != "" ? var.sql_server_name : "sql-${local.workload_slug}-${local.effective_environment}"
  sql_database_name              = trimspace(var.sql_database_name) != "" ? var.sql_database_name : "sqldb-${local.workload_slug}-${local.effective_environment}"
  sql_administrator_login        = var.sql_administrator_login == null ? "" : var.sql_administrator_login
  sql_administrator_password     = var.sql_administrator_password == null ? "" : var.sql_administrator_password
  sql_admin_credentials_key_vault_id = (
    trimspace(var.sql_admin_credentials_key_vault_id) != ""
    ? var.sql_admin_credentials_key_vault_id
    : data.azurerm_key_vault.landingzone.id
  )

  common_tags = merge(
    {
      for key, value in var.rg_tags : key => value
    },
    {
      Workload   = var.workload
      Purpose    = "document-extraction"
      managed_by = "terraform"
    },
    {
      for key, value in var.tags : key => value
      if !contains(["workload", "environment"], lower(key))
    }
  )
}

# -------------------------------------------------------------------
# Resource Group
# -------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  count    = local.create_resource_group ? 1 : 0
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# -------------------------------------------------------------------
# Azure OpenAI Deployments on Landingzone Account
# -------------------------------------------------------------------

resource "azurerm_cognitive_deployment" "extraction_chat" {
  count = var.create_azure_openai_chat_deployment && local.landingzone_openai_lookup_enabled && length(data.azurerm_cognitive_account.openai) > 0 ? 1 : 0

  name                 = local.openai_chat_deployment_name
  cognitive_account_id = data.azurerm_cognitive_account.openai[0].id

  model {
    format  = "OpenAI"
    name    = var.azure_openai_chat_model_name
    version = var.azure_openai_chat_model_version
  }

  sku {
    name     = var.azure_openai_chat_deployment_sku_name
    capacity = var.azure_openai_chat_deployment_capacity
  }
}

# -------------------------------------------------------------------
# Azure Functions
# -------------------------------------------------------------------

module "function_app_service_plan" {
  count  = var.enable_function_app ? 1 : 0
  source = "git::https://dev.azure.com/CCOE-Azure/IaC/_git/template//modules/appserviceplan?ref=main"

  name                = local.function_plan_name
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  os_type             = "Linux"
  sku_name            = var.function_plan_sku_name

  enable_diagnostics         = var.function_plan_enable_diagnostics
  log_analytics_workspace_id = var.function_plan_enable_diagnostics ? data.azurerm_log_analytics_workspace.landingzone.id : null
  enable_autoscale           = false

  app_env = local.module_app_env
  tags    = local.common_tags
}

module "functionapp" {
  count  = var.enable_function_app ? 1 : 0
  source = "git::https://dev.azure.com/CCOE-Azure/IaC/_git/template//modules/functionapp?ref=main"

  resource_group_name                 = local.resource_group_name
  name                                = local.function_app_name
  location                            = local.resource_group_location
  service_plan_id                     = module.function_app_service_plan[0].id
  storage_account_name                = data.azurerm_storage_account.iac.name
  storage_account_resource_group_name = data.azurerm_resource_group.iac.name
  system_assigned_identity_enabled    = true
  public_network_access_enabled       = var.function_public_network_access_enabled
  always_on                           = var.function_plan_sku_name == "Y1" ? false : true
  application_stack = {
    python_version = var.function_python_version
  }

  app_settings = merge(
    {
      FUNCTIONS_WORKER_RUNTIME       = "python"
      AzureWebJobsFeatureFlags       = "EnableWorkerIndexing"
      DOCUMENT_INTELLIGENCE_ENDPOINT = local.document_intelligence_endpoint
      AZURE_OPENAI_ENDPOINT          = local.azure_openai_endpoint
      AZURE_OPENAI_CHAT_DEPLOYMENT   = local.openai_chat_app_setting_name
      SQL_SERVER_FQDN                = module.sqldb.server_fqdn
      SQL_DATABASE_NAME              = module.sqldb.database_name
    },
    var.function_app_settings
  )

  enable_diagnostics         = var.function_enable_diagnostics
  log_analytics_workspace_id = var.function_enable_diagnostics ? data.azurerm_log_analytics_workspace.landingzone.id : ""
  app_admin_group            = var.app_admin_group
  app_user_group             = var.app_user_group
  tags                       = local.common_tags

  depends_on = [
    module.function_app_service_plan,
    module.sqldb
  ]
}

# -------------------------------------------------------------------
# Azure Logic Apps
# -------------------------------------------------------------------

resource "azurerm_logic_app_workflow" "document_processing" {
  name                = local.logic_app_name
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  enabled             = true
  tags                = local.common_tags

  identity {
    type = "SystemAssigned"
  }
}

# -------------------------------------------------------------------
# Azure SQL Database
# -------------------------------------------------------------------

module "sqldb" {
  source = "git::https://dev.azure.com/CCOE-Azure/IaC/_git/template//modules/sqldb?ref=main"

  server_name                    = local.sql_server_name
  database_name                  = local.sql_database_name
  max_size_gb                    = var.sql_database_max_size_gb
  backup_storage_redundancy      = var.sql_backup_storage_redundancy
  public_network_access_enabled  = var.sql_public_network_access_enabled
  firewall_rules                 = var.sql_firewall_rules
  admin_username                 = local.sql_administrator_login
  admin_password                 = local.sql_administrator_password
  admin_credentials_key_vault_id = local.sql_admin_credentials_key_vault_id
  admin_username_secret_name     = var.sql_admin_username_secret_name
  admin_password_secret_name     = var.sql_admin_password_secret_name
  ad_admin_login_name            = var.sql_ad_admin_login_name
  ad_admin_object_id             = var.sql_ad_admin_object_id
  sku_name                       = var.sql_database_sku_name
  resource_group_name            = local.resource_group_name
  app_env                        = local.module_app_env
  location                       = local.resource_group_location
  private_endpoint_subnet_id     = var.sql_private_endpoint_subnet_id
  private_dns_zone_ids           = var.sql_private_dns_zone_ids
  enable_private_endpoint        = var.sql_enable_private_endpoint
  enable_diagnostics             = var.sql_enable_diagnostics
  log_analytics_workspace_id     = var.sql_enable_diagnostics ? data.azurerm_log_analytics_workspace.landingzone.id : ""
  app_admin_group                = var.app_admin_group
  app_user_group                 = var.app_user_group
  tags                           = local.common_tags

  depends_on = [
    azurerm_resource_group.this
  ]
}

# -------------------------------------------------------------------
# Managed Identity Access
# -------------------------------------------------------------------

resource "azurerm_role_assignment" "function_document_intelligence_user" {
  count = var.enable_function_app && local.landingzone_azure_ai_service_lookup_enabled && length(data.azurerm_cognitive_account.azure_ai_service) > 0 ? 1 : 0

  scope                = data.azurerm_cognitive_account.azure_ai_service[0].id
  role_definition_name = "Cognitive Services User"
  principal_id         = module.functionapp[0].identity_principal_id
}

resource "azurerm_role_assignment" "function_openai_user" {
  count = var.enable_function_app && local.landingzone_openai_lookup_enabled && length(data.azurerm_cognitive_account.openai) > 0 ? 1 : 0

  scope                = data.azurerm_cognitive_account.openai[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = module.functionapp[0].identity_principal_id
}

resource "azurerm_role_assignment" "logic_app_document_intelligence_user" {
  count = local.landingzone_azure_ai_service_lookup_enabled && length(data.azurerm_cognitive_account.azure_ai_service) > 0 ? 1 : 0

  scope                = data.azurerm_cognitive_account.azure_ai_service[0].id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_logic_app_workflow.document_processing.identity[0].principal_id
}

resource "azurerm_role_assignment" "logic_app_openai_user" {
  count = local.landingzone_openai_lookup_enabled && length(data.azurerm_cognitive_account.openai) > 0 ? 1 : 0

  scope                = data.azurerm_cognitive_account.openai[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azurerm_logic_app_workflow.document_processing.identity[0].principal_id
}
