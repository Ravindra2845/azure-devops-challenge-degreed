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

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "degreed-challenge-rg-central"
  location = "centralus" # CHANGED: Main US region often has quota
}

resource "random_pet" "suffix" {
  length = 2
}

resource "random_password" "sql_admin" {
  length  = 16
  special = true
}

# --- DATABASE ---
resource "azurerm_mssql_server" "sql" {
  name                         = "sql-${random_pet.suffix.id}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = random_password.sql_admin.result
  public_network_access_enabled = true
}

resource "azurerm_mssql_database" "db" {
  name      = "QuotesDB"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "S0" 
}

resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzure"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# --- KEY VAULT ---
resource "azurerm_key_vault" "kv" {
  name                = "kv-${random_pet.suffix.id}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = ["Set", "Get", "Delete", "Purge", "Recover"]
  }
}

resource "azurerm_key_vault_secret" "conn_str" {
  name         = "SQL-CONN-STR"
  value        = "Driver={ODBC Driver 18 for SQL Server};Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.db.name};Uid=sqladmin;Pwd=${random_password.sql_admin.result};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.kv.id
  depends_on   = [azurerm_key_vault.kv]
}

# --- APP SERVICE ---
resource "azurerm_service_plan" "plan" {
  name                = "degreed-plan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1" # Free Tier
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-${random_pet.suffix.id}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.plan.location
  service_plan_id     = azurerm_service_plan.plan.id

  site_config {
    application_stack {
      python_version = "3.9"
    }
    always_on = false
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    "SQL_CONN_STR" = "Driver={ODBC Driver 18 for SQL Server};Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.db.name};Uid=sqladmin;Pwd=${random_password.sql_admin.result};Encrypt=yes;TrustServerCertificate=yes;Connection Timeout=30;"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
  }
}

resource "azurerm_key_vault_access_policy" "app_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.app.identity[0].principal_id
  secret_permissions = ["Get"]
}

output "webapp_url" {
  value = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "db_server" {
  value = azurerm_mssql_server.sql.fully_qualified_domain_name
}
output "db_user" {
  value = "sqladmin"
}
output "db_pass" {
  value     = random_password.sql_admin.result
  sensitive = true
}
