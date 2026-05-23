terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      version               = ">= 4.0"
      configuration_aliases = [azurerm.prod]
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
  }
}
