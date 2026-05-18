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
  app_service_private_dns_zone_name           = trimspace(var.app_service_private_dns_zone_name) != "" ? trimspace(var.app_service_private_dns_zone_name) : "privatelink.azurewebsites.net"
  app_service_private_dns_zone_resource_group = trimspace(var.app_service_private_dns_zone_resource_group_name) != "" ? trimspace(var.app_service_private_dns_zone_resource_group_name) : local.resource_group_name
  app_service_private_dns_zone_id             = trimspace(var.app_service_private_dns_zone_id) != "" ? var.app_service_private_dns_zone_id : null
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
    azurerm = azurerm
  }

  app_name            = local.app_service_name
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  app_service_plan_id = module.app_service_plan[0].id

  kind                              = "Linux"
  auth_mode                         = local.app_service_auth_mode
  allow_anonymous                   = true
  public_network_access_enabled     = var.app_service_public_network_access_enabled
  ip_restrictions                   = var.app_service_ip_restrictions
  ip_restriction_default_action     = var.app_service_ip_restriction_default_action
  websockets_enabled                = true
  always_on                         = true
  http2_enabled                     = true
  health_check_path                 = "/healthz"
  health_check_eviction_time_in_min = 2
  system_assigned_identity_enabled  = true

  scm_basic_auth_publishing_credentials_enabled = var.app_service_scm_basic_auth_publishing_credentials_enabled
  scm_use_main_ip_restriction                   = var.app_service_scm_use_main_ip_restriction
  active_directory_client_id                    = var.app_service_enable_auth ? module.app_registration_appservice[0].application_id : null
  log_analytics_workspace_id                    = local.log_analytics_workspace_id
  enable_private_endpoint                       = var.app_service_enable_private_endpoint
  private_endpoint_subnet_id                    = var.app_service_private_endpoint_subnet_id
  private_endpoint_subnet_name                  = var.app_service_private_endpoint_subnet_name
  private_endpoint_vnet_name                    = var.app_service_private_endpoint_vnet_name
  private_endpoint_network_resource_group_name  = var.app_service_private_endpoint_network_resource_group_name
  private_dns_zone_id                           = local.app_service_private_dns_zone_id
  private_dns_zone_name                         = local.app_service_private_dns_zone_id == null ? local.app_service_private_dns_zone_name : null
  private_dns_zone_resource_group_name          = local.app_service_private_dns_zone_id == null ? local.app_service_private_dns_zone_resource_group : null

  app_settings = merge(
    local.app_service_app_settings,
    var.azure_search_query_key != "" ? {
      AZURE_SEARCH_QUERY_KEY = var.azure_search_query_key
    } : {},
    {
      AZURE_OPENAI_ENDPOINT          = local.azure_openai_endpoint
      AZURE_AI_SERVICE_ENDPOINT      = local.azure_ai_service_endpoint
      AZURE_OPENAI_CHAT_DEPLOYMENT   = local.rag_chat_app_setting_name
      AZURE_OPENAI_EMBED_DEPLOYMENT  = local.rag_embed_app_setting_name
      AZURE_SEARCH_ENDPOINT          = local.azure_ai_search_endpoint
      AZURE_SEARCH_INDEX             = local.rag_search_index_name
      STORAGE_ACCOUNT_NAME           = data.azurerm_storage_account.landingzone.name
      STORAGE_CONTAINER_NAME         = local.rag_container_app_setting_name
      SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
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

# -------------------------------------------------------------------
# Enterprise RAG Support
# -------------------------------------------------------------------

locals {
  rag_chat_deployment_name       = var.azure_openai_chat_deployment != "" ? var.azure_openai_chat_deployment : "chat"
  rag_embed_deployment_name      = var.azure_openai_embed_deployment != "" ? var.azure_openai_embed_deployment : "embedding"
  rag_search_index_name          = var.azure_search_index != "" ? var.azure_search_index : "enterprise-docs"
  rag_chat_app_setting_name      = length(azurerm_cognitive_deployment.rag_chat) > 0 ? azurerm_cognitive_deployment.rag_chat[0].name : local.rag_chat_deployment_name
  rag_embed_app_setting_name     = length(azurerm_cognitive_deployment.rag_embedding) > 0 ? azurerm_cognitive_deployment.rag_embedding[0].name : local.rag_embed_deployment_name
  rag_container_app_setting_name = azurerm_storage_container.rag_documents.name
}

resource "azurerm_storage_container" "rag_documents" {
  name                  = var.rag_storage_container_name
  storage_account_id    = data.azurerm_storage_account.landingzone.id
  container_access_type = "private"
}

resource "azurerm_cognitive_deployment" "rag_chat" {
  count = local.landingzone_openai_lookup_enabled && length(data.azurerm_cognitive_account.openai) > 0 ? 1 : 0

  name                 = local.rag_chat_deployment_name
  cognitive_account_id = data.azurerm_cognitive_account.openai[0].id

  model {
    format  = "OpenAI"
    name    = var.rag_openai_chat_model_name
    version = var.rag_openai_chat_model_version
  }

  sku {
    name     = var.rag_openai_chat_deployment_sku_name
    capacity = var.rag_openai_chat_deployment_capacity
  }
}

resource "azurerm_cognitive_deployment" "rag_embedding" {
  count = local.landingzone_openai_lookup_enabled && length(data.azurerm_cognitive_account.openai) > 0 ? 1 : 0

  name                 = local.rag_embed_deployment_name
  cognitive_account_id = data.azurerm_cognitive_account.openai[0].id

  model {
    format  = "OpenAI"
    name    = var.rag_openai_embedding_model_name
    version = var.rag_openai_embedding_model_version
  }

  sku {
    name     = var.rag_openai_embedding_deployment_sku_name
    capacity = var.rag_openai_embedding_deployment_capacity
  }
}

resource "azurerm_role_assignment" "app_openai_user" {
  count = var.enable_app_service_stack && local.landingzone_openai_lookup_enabled && length(data.azurerm_cognitive_account.openai) > 0 ? 1 : 0

  scope                = data.azurerm_cognitive_account.openai[0].id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = module.app_service[0].identity_principal_id
}

resource "azurerm_role_assignment" "app_search_index_data_reader" {
  count = var.enable_app_service_stack && var.landingzone_azure_ai_search_enabled && length(data.azurerm_search_service.azure_ai_search) > 0 ? 1 : 0

  scope                = data.azurerm_search_service.azure_ai_search[0].id
  role_definition_name = "Search Index Data Reader"
  principal_id         = module.app_service[0].identity_principal_id
}

resource "azurerm_role_assignment" "app_storage_blob_data_reader" {
  count = var.enable_app_service_stack ? 1 : 0

  scope                = data.azurerm_storage_account.landingzone.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = module.app_service[0].identity_principal_id
}

resource "azurerm_role_assignment" "app_ai_service_user" {
  count = var.enable_app_service_stack && local.landingzone_azure_ai_service_lookup_enabled && length(data.azurerm_cognitive_account.azure_ai_service) > 0 ? 1 : 0

  scope                = data.azurerm_cognitive_account.azure_ai_service[0].id
  role_definition_name = "Cognitive Services User"
  principal_id         = module.app_service[0].identity_principal_id
}

# -------------------------------------------------------------------
# Optional Private Endpoints and DNS Zone Wiring
# -------------------------------------------------------------------
# The docs project created new private DNS zones and private endpoints.
# In this root module, those dependencies should come from the landingzone
# where possible, so the migrated blocks are intentionally disabled for now.
# Uncomment and adapt the IDs/names only when private endpoints are required
# for this workload.
#
# data "azurerm_subnet" "rag_private_endpoints" {
#   name                 = var.app_service_private_endpoint_subnet_name
#   virtual_network_name = var.app_service_private_endpoint_vnet_name
#   resource_group_name  = var.app_service_private_endpoint_network_resource_group_name
# }
#
# data "azurerm_private_dns_zone" "rag_openai" {
#   name                = "privatelink.openai.azure.com"
#   resource_group_name = var.app_service_private_dns_zone_resource_group_name
# }
#
# data "azurerm_private_dns_zone" "rag_search" {
#   name                = "privatelink.search.windows.net"
#   resource_group_name = var.app_service_private_dns_zone_resource_group_name
# }
#
# data "azurerm_private_dns_zone" "rag_blob" {
#   name                = "privatelink.blob.core.windows.net"
#   resource_group_name = var.app_service_private_dns_zone_resource_group_name
# }
#
# data "azurerm_private_dns_zone" "rag_vault" {
#   name                = "privatelink.vaultcore.azure.net"
#   resource_group_name = var.app_service_private_dns_zone_resource_group_name
# }
#
# resource "azurerm_private_endpoint" "rag_openai" {
#   name                = "pe-openai-${local.workload_slug}-${local.effective_environment}"
#   resource_group_name = local.resource_group_name
#   location            = local.resource_group_location
#   subnet_id           = data.azurerm_subnet.rag_private_endpoints.id
#   tags                = local.common_tags
#
#   private_service_connection {
#     name                           = "psc-openai"
#     private_connection_resource_id = data.azurerm_cognitive_account.openai[0].id
#     subresource_names              = ["account"]
#     is_manual_connection           = false
#   }
#
#   private_dns_zone_group {
#     name                 = "default"
#     private_dns_zone_ids = [data.azurerm_private_dns_zone.rag_openai.id]
#   }
# }
#
# resource "azurerm_private_endpoint" "rag_search" {
#   name                = "pe-search-${local.workload_slug}-${local.effective_environment}"
#   resource_group_name = local.resource_group_name
#   location            = local.resource_group_location
#   subnet_id           = data.azurerm_subnet.rag_private_endpoints.id
#   tags                = local.common_tags
#
#   private_service_connection {
#     name                           = "psc-search"
#     private_connection_resource_id = data.azurerm_search_service.azure_ai_search[0].id
#     subresource_names              = ["searchService"]
#     is_manual_connection           = false
#   }
#
#   private_dns_zone_group {
#     name                 = "default"
#     private_dns_zone_ids = [data.azurerm_private_dns_zone.rag_search.id]
#   }
# }
#
# resource "azurerm_private_endpoint" "rag_blob" {
#   name                = "pe-blob-${local.workload_slug}-${local.effective_environment}"
#   resource_group_name = local.resource_group_name
#   location            = local.resource_group_location
#   subnet_id           = data.azurerm_subnet.rag_private_endpoints.id
#   tags                = local.common_tags
#
#   private_service_connection {
#     name                           = "psc-blob"
#     private_connection_resource_id = data.azurerm_storage_account.landingzone.id
#     subresource_names              = ["blob"]
#     is_manual_connection           = false
#   }
#
#   private_dns_zone_group {
#     name                 = "default"
#     private_dns_zone_ids = [data.azurerm_private_dns_zone.rag_blob.id]
#   }
# }
#
# resource "azurerm_private_endpoint" "rag_key_vault" {
#   name                = "pe-kv-${local.workload_slug}-${local.effective_environment}"
#   resource_group_name = local.resource_group_name
#   location            = local.resource_group_location
#   subnet_id           = data.azurerm_subnet.rag_private_endpoints.id
#   tags                = local.common_tags
#
#   private_service_connection {
#     name                           = "psc-kv"
#     private_connection_resource_id = data.azurerm_key_vault.landingzone.id
#     subresource_names              = ["vault"]
#     is_manual_connection           = false
#   }
#
#   private_dns_zone_group {
#     name                 = "default"
#     private_dns_zone_ids = [data.azurerm_private_dns_zone.rag_vault.id]
#   }
# }
