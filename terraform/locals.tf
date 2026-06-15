# -------------------------------------------------------------------
# Naming and Shared Values
# -------------------------------------------------------------------

locals {
  workload_slug                   = lower(replace(var.workload, "_", "-"))
  effective_environment           = trimspace(var.environment) != "" ? lower(var.environment) : "dev"
  landingzone_resource_group_name = var.landingzone_resource_group_name != "" ? var.landingzone_resource_group_name : var.landingzone_ai_resource_group_name
  create_resource_group           = trimspace(var.resource_group_name) != ""
  resource_group_name             = local.create_resource_group ? var.resource_group_name : data.azurerm_resource_group.landingzone.name
  resource_group_location         = local.create_resource_group ? var.location : data.azurerm_resource_group.landingzone.location
  module_app_env                  = local.effective_environment == "sandbox" ? "sbx" : local.effective_environment
  feature_flags = {
    enable_app_service_stack               = lookup(var.features, "enable_app_service_stack", var.enable_app_service_stack)
    enable_app_registration_for_appservice = lookup(var.features, "enable_app_registration_for_appservice", true)
    enable_openai                          = lookup(var.features, "enable_openai", var.landingzone_openai_enabled)
    enable_azure_ai_service                = lookup(var.features, "enable_azure_ai_service", var.landingzone_azure_ai_service_enabled)
    enable_azure_ai_search                 = lookup(var.features, "enable_azure_ai_search", var.landingzone_azure_ai_search_enabled)
    create_azure_search_query_key          = lookup(var.features, "create_azure_search_query_key", var.create_azure_search_query_key)
  }
  landingzone_openai_lookup_enabled           = local.effective_environment == "dev" ? false : local.feature_flags.enable_openai
  landingzone_azure_ai_service_lookup_enabled = local.effective_environment == "dev" ? false : local.feature_flags.enable_azure_ai_service
  landingzone_azure_ai_search_lookup_enabled  = local.feature_flags.enable_azure_ai_search
  app_registration_enabled                    = local.feature_flags.enable_app_service_stack && local.feature_flags.enable_app_registration_for_appservice
  app_service_plan_name                       = var.app_service_plan_name != "" ? var.app_service_plan_name : "asp-${local.workload_slug}-${local.effective_environment}"
  app_service_name                            = var.app_service_name != "" ? var.app_service_name : "web-${local.workload_slug}-${local.effective_environment}"
  app_registration_name                       = var.app_registration_display_name != "" ? var.app_registration_display_name : "appreg-${local.workload_slug}-${local.effective_environment}"
  app_default_hostname                        = "${local.app_service_name}.azurewebsites.net"
  app_service_private_dns_zone_name           = trimspace(var.app_service_private_dns_zone_name) != "" ? trimspace(var.app_service_private_dns_zone_name) : "privatelink.azurewebsites.net"
  app_service_private_dns_zone_resource_group = trimspace(var.app_service_private_dns_zone_resource_group_name) != "" ? trimspace(var.app_service_private_dns_zone_resource_group_name) : local.resource_group_name
  app_service_private_dns_zone_id             = trimspace(var.app_service_private_dns_zone_id) != "" ? var.app_service_private_dns_zone_id : null
  app_service_auth_mode                       = var.app_service_enable_auth && local.app_registration_enabled ? "msal" : "none"
  log_analytics_workspace_id                  = data.azurerm_log_analytics_workspace.landingzone.id
  azure_openai_endpoint                       = local.landingzone_openai_lookup_enabled && length(data.azurerm_cognitive_account.openai) > 0 ? try(data.azurerm_cognitive_account.openai[0].endpoint, "https://${data.azurerm_cognitive_account.openai[0].name}.openai.azure.com/") : ""
  azure_ai_service_endpoint                   = local.landingzone_azure_ai_service_lookup_enabled && length(data.azurerm_cognitive_account.azure_ai_service) > 0 ? try(data.azurerm_cognitive_account.azure_ai_service[0].endpoint, "https://${data.azurerm_cognitive_account.azure_ai_service[0].name}.cognitiveservices.azure.com/") : ""
  azure_ai_search_endpoint                    = local.landingzone_azure_ai_search_lookup_enabled && length(data.azurerm_search_service.azure_ai_search) > 0 ? "https://${data.azurerm_search_service.azure_ai_search[0].name}.search.windows.net" : ""
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
      Workload = var.workload
    },
    {
      for key, value in var.tags : key => value
      if !contains(["workload", "environment"], lower(key))
    }
  )
}

locals {
  rag_chat_deployment_name       = var.azure_openai_chat_deployment != "" ? var.azure_openai_chat_deployment : "chat"
  rag_embed_deployment_name      = var.azure_openai_embed_deployment != "" ? var.azure_openai_embed_deployment : "embedding"
  rag_search_index_name          = var.azure_search_index != "" ? var.azure_search_index : "enterprise-docs"
  rag_search_query_key           = var.azure_search_query_key != "" ? var.azure_search_query_key : (length(azapi_resource_action.rag_search_query_key) > 0 ? azapi_resource_action.rag_search_query_key[0].sensitive_output.key : "")
  rag_chat_app_setting_name      = length(azurerm_cognitive_deployment.rag_chat) > 0 ? azurerm_cognitive_deployment.rag_chat[0].name : local.rag_chat_deployment_name
  rag_embed_app_setting_name     = length(azurerm_cognitive_deployment.rag_embedding) > 0 ? azurerm_cognitive_deployment.rag_embedding[0].name : local.rag_embed_deployment_name
  rag_container_app_setting_name = azurerm_storage_container.rag_documents.name
}
