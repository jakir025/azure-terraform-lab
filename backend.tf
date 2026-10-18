terraform {
  backend "azurerm" {
    resource_group_name  = "lab-jkl-2"
    storage_account_name = "jakirtfstate2026"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}