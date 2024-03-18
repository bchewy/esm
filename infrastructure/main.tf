terraform {


  # backend "azurerm" {
  #   resource_group_name  = "tfstate"
  #   storage_account_name = "tfstatebchewy"
  #   container_name       = "tfstate"
  #   key                  = "terraform.tfstate"
  # }

}
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  # Brian's Subscription ID
  subscription_id = "6d07e33b-f071-4121-9c74-7c575bafc191"
}

# Terraform items to store our tf state
# module "states" {
#   source = "./modules/states"
# }

# module "dev" {
#   source = "./modules/0-dev"
# }

# module "test" {
#   source = "./modules/1-test"
# }

# module "staging" {
#   source = "./modules/2-staging"
# }

module "prod" {
  source = "./modules/3-prod"
}
