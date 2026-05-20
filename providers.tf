provider "azurerm" {
  subscription_id = var.subscription_id != "" ? var.subscription_id : null

  features {}
}

provider "azuread" {}
