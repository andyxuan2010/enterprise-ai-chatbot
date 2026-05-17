# -------------------------------------------------------------------
# Naming and Shared Values
# -------------------------------------------------------------------

locals {
  workload_slug                               = lower(replace(var.workload, "_", "-"))
  effective_environment                       = trimspace(var.environment) != "" ? lower(var.environment) : "dev"
  landingzone_resource_group_name             = var.landingzone_resource_group_name != "" ? var.landingzone_resource_group_name : var.landingzone_ai_resource_group_name
  create_resource_group                       = trimspace(var.resource_group_name) != ""
  resource_group_name                         = local.create_resource_group ? var.resource_group_name : data.azurerm_resource_group.landingzone.name
  resource_group_location                     = local.create_resource_group ? var.location : data.azurerm_resource_group.landingzone.location
  module_app_env                              = local.effective_environment == "sandbox" ? "sbx" : local.effective_environment
  landingzone_openai_lookup_enabled           = local.effective_environment == "dev" ? false : var.landingzone_openai_enabled
  landingzone_azure_ai_service_lookup_enabled = local.effective_environment == "dev" ? false : var.landingzone_azure_ai_service_enabled
  app_service_plan_name                       = var.app_service_plan_name != "" ? var.app_service_plan_name : "asp-${local.workload_slug}-${local.effective_environment}"
  app_service_name                            = var.app_service_name != "" ? var.app_service_name : "app-${local.workload_slug}-${local.effective_environment}"
  app_registration_name                       = var.app_registration_display_name != "" ? var.app_registration_display_name : "appreg-${local.workload_slug}-${local.effective_environment}"
  app_default_hostname                        = "${local.app_service_name}.azurewebsites.net"
  app_service_auth_mode                       = var.app_service_enable_auth ? "msal" : "none"
  log_analytics_workspace_id                  = data.azurerm_log_analytics_workspace.landingzone.id
  azure_openai_endpoint                       = local.landingzone_openai_lookup_enabled && length(data.azurerm_cognitive_account.openai) > 0 ? try(data.azurerm_cognitive_account.openai[0].endpoint, "https://${data.azurerm_cognitive_account.openai[0].name}.openai.azure.com/") : ""
  azure_ai_service_endpoint                   = local.landingzone_azure_ai_service_lookup_enabled && length(data.azurerm_cognitive_account.azure_ai_service) > 0 ? try(data.azurerm_cognitive_account.azure_ai_service[0].endpoint, "https://${data.azurerm_cognitive_account.azure_ai_service[0].name}.cognitiveservices.azure.com/") : ""
  azure_ai_search_endpoint                    = var.landingzone_azure_ai_search_enabled && length(data.azurerm_search_service.azure_ai_search) > 0 ? "https://${data.azurerm_search_service.azure_ai_search[0].name}.search.windows.net" : ""
  app_service_app_settings = merge(
    {
      SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
      ENABLE_ORYX_BUILD              = "true"
    },
    var.app_service_app_settings
  )
  common_tags = merge(
    {
      for key, value in var.rg_tags : key => value
    },
    {
      Workload   = var.workload
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
# App Service Plan
# -------------------------------------------------------------------

module "app_service_plan" {
  count  = var.enable_app_service_stack ? 1 : 0
  source = "git::https://dev.azure.com/CCOE-Azure/IaC/_git/template//modules/appserviceplan?ref=main"

  name                = local.app_service_plan_name
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku_name

  enable_diagnostics         = false
  log_analytics_workspace_id = local.log_analytics_workspace_id
  enable_autoscale           = false

  app_env = local.module_app_env
  tags    = local.common_tags
}

# -------------------------------------------------------------------
# App Registration
# -------------------------------------------------------------------

module "app_registration_appservice" {
  count  = var.enable_app_service_stack ? 1 : 0
  source = "git::https://dev.azure.com/CCOE-Azure/IaC/_git/template//modules/appregistration?ref=main"

  display_name                   = local.app_registration_name
  app_service_redirect_hostnames = [local.app_default_hostname]
  app_service_auth_mode          = "msal"
  create_service_principal       = true
  create_client_secret           = var.app_registration_create_client_secret
  add_current_caller_as_owner    = true
}

# -------------------------------------------------------------------
# Python App Service
# -------------------------------------------------------------------

module "app_service" {
  count  = var.enable_app_service_stack ? 1 : 0
  source = "git::https://dev.azure.com/CCOE-Azure/IaC/_git/template//modules/appservice?ref=main"

  providers = {
    azurerm      = azurerm
    azurerm.prod = azurerm.prod
  }

  app_name            = local.app_service_name
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  app_service_plan_id = module.app_service_plan[0].id

  kind                              = "Linux"
  auth_mode                         = local.app_service_auth_mode
  allow_anonymous                   = true
  public_network_access_enabled     = true
  ip_restrictions                   = var.app_service_ip_restrictions
  ip_restriction_default_action     = var.app_service_ip_restriction_default_action
  websockets_enabled                = true
  always_on                         = true
  http2_enabled                     = true
  health_check_path                 = "/healthz"
  health_check_eviction_time_in_min = 2
  system_assigned_identity_enabled  = true

  scm_basic_auth_publishing_credentials_enabled = var.app_service_scm_basic_auth_publishing_credentials_enabled
  active_directory_client_id                    = var.app_service_enable_auth ? module.app_registration_appservice[0].application_id : null
  log_analytics_workspace_id                    = local.log_analytics_workspace_id

  app_settings = merge(
    local.app_service_app_settings,
    {
      AZURE_OPENAI_ENDPOINT         = local.azure_openai_endpoint
      AZURE_AI_SERVICE_ENDPOINT     = local.azure_ai_service_endpoint
      AZURE_OPENAI_CHAT_DEPLOYMENT  = var.azure_openai_chat_deployment
      AZURE_OPENAI_EMBED_DEPLOYMENT = var.azure_openai_embed_deployment
      AZURE_SEARCH_ENDPOINT         = local.azure_ai_search_endpoint
      AZURE_SEARCH_INDEX            = var.azure_search_index
    }
  )

  app_command_line = "bash startup.sh"
  application_stack = {
    current_stack  = "python"
    python_version = var.app_service_python_version
  }

  app_env = local.module_app_env
  tags    = local.common_tags

  depends_on = [
    module.app_service_plan,
    module.app_registration_appservice
  ]
}
