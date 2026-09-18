provider "azurerm" {
  subscription_id = var.subscription_id != "" ? var.subscription_id : null

  features {}
}

provider "azurerm" {
  alias           = "prod"
  subscription_id = var.subscription_id != "" ? var.subscription_id : null

  features {}
}

provider "azuread" {}
