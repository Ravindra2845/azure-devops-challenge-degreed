terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "degreed-challenge-rg-central"
  location = "centralus"
}

resource "random_pet" "suffix" {
  length = 2
}

resource "random_password" "sql_admin" {
  length  = 16
  special = true
}

module "database" {
  source         = "./modules/database"
  rg_name        = azurerm_resource_group.rg.name
  location       = azurerm_resource_group.rg.location
  suffix         = random_pet.suffix.id
  admin_user     = "sqladmin"
  admin_password = random_password.sql_admin.result
}

# Construct the connection string here to pass it to both App and Vault
locals {
  conn_str = "Driver={ODBC Driver 18 for SQL Server};Server=tcp:${module.database.server_fqdn},1433;Database=${module.database.db_name};Uid=sqladmin;Pwd=${random_password.sql_admin.result};Encrypt=yes;TrustServerCertificate=yes;Connection Timeout=30;"
}

module "webapp" {
  source            = "./modules/webapp"
  rg_name           = azurerm_resource_group.rg.name
  location          = azurerm_resource_group.rg.location
  suffix            = random_pet.suffix.id
  connection_string = local.conn_str
}

module "security" {
  source              = "./modules/security"
  rg_name             = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  suffix              = random_pet.suffix.id
  connection_string   = local.conn_str
  webapp_principal_id = module.webapp.principal_id
}

output "webapp_name" {
  value = module.webapp.app_name
}

output "webapp_url" {
  value = "https://${module.webapp.hostname}"
}