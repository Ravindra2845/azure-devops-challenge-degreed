resource "azurerm_service_plan" "plan" {
  name                = "degreed-plan"
  resource_group_name = var.rg_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "app" {
  name                = "app-${var.suffix}"
  resource_group_name = var.rg_name
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
    "SQL_CONN_STR" = var.connection_string
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
  }
}