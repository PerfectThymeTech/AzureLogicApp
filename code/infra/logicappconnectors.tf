data "azurerm_managed_api" "managed_api_arm" {
  name     = "arm"
  location = var.location
}

resource "azurerm_api_connection" "api_connection_arm" {
  name                = "${local.prefix}-api-arm001"
  resource_group_name = azurerm_resource_group.app_rg.name
  tags                = var.tags

  display_name   = "AzureResourceManagerApiConnection"
  managed_api_id = data.azurerm_managed_api.managed_api_arm.id
  parameter_values = {
    managedIdentityAuth = "{}"
  }

  lifecycle {
    # NOTE: since the connectionString is a secure value it's not returned from the API
    ignore_changes = [
      parameter_values
    ]
  }
}
