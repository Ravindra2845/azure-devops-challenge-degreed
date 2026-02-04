resource "azurerm_mssql_server" "sql" {
  name                         = "sql-${var.suffix}"
  resource_group_name          = var.rg_name
  location                     = var.location
  version                      = "12.0"
  administrator_login          = var.admin_user
  administrator_login_password = var.admin_password
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