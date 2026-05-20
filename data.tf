data "azurerm_resource_group" "landingzone" {
  name = local.landingzone_resource_group_name
}

data "azurerm_resource_group" "iac" {
  name = local.iac_resource_group_name
}

data "azurerm_storage_account" "iac" {
  name                = local.storage_account_name
  resource_group_name = data.azurerm_resource_group.iac.name
}

data "azurerm_key_vault" "landingzone" {
  name                = local.key_vault_name
  resource_group_name = data.azurerm_resource_group.iac.name
}

data "azurerm_cognitive_account" "openai" {
  count = local.landingzone_openai_lookup_enabled ? 1 : 0

  name                = var.landingzone_openai_name
  resource_group_name = data.azurerm_resource_group.landingzone.name
}

data "azurerm_cognitive_account" "azure_ai_service" {
  count = local.landingzone_azure_ai_service_lookup_enabled ? 1 : 0

  name                = var.landingzone_azure_ai_service_name
  resource_group_name = data.azurerm_resource_group.landingzone.name
}

data "azurerm_log_analytics_workspace" "landingzone" {
  name                = var.landingzone_log_analytics_name
  resource_group_name = data.azurerm_resource_group.landingzone.name
}
