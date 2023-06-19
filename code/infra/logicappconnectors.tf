data "azurerm_managed_api" "managed_api_arm" {
  name     = "arm"
  location = var.location
}

resource "azurerm_api_connection" "api_connection_arm" {
  name                = "${local.prefix}-api-arm001"
  resource_group_name = azurerm_resource_group.app_rg.name
  tags                = var.tags

  display_name     = "AzureResourceManagerApiConnection"
  managed_api_id   = data.azurerm_managed_api.managed_api_arm.id
  parameter_values = {}

  # lifecycle {
  #   # NOTE: since the connectionString is a secure value it's not returned from the API
  #   ignore_changes = [
  #     parameter_values
  #   ]
  # }
}

# resource "azapi_resource" "api_connection_arm" {
#   type      = "Microsoft.Web/connections@2016-06-01"
#   parent_id = azurerm_resource_group.app_rg.id
#   name      = "${local.prefix}-api-arm001"
#   location  = var.location
#   tags      = var.tags

#   body = jsonencode({
#     properties = {
#       api = {
#         name        = data.azurerm_managed_api.managed_api_arm.name
#         displayName = "Azure Resource Manager"
#         description = "Azure Resource Manager exposes the APIs to manage all of your Azure resources."
#         iconUri     = "https://connectoricons-prod.azureedge.net/u/shgogna/globalperconnector-train1/1.0.1639.3310/${data.azurerm_managed_api.managed_api_arm.name}/icon.png"
#         brandColor  = "#003056"
#         id          = data.azurerm_managed_api.managed_api_arm.id
#         type        = "Microsoft.Web/locations/managedApis"
#       }
#       customParameterValues = {}
#       # nonSecretParameterValues = {}
#       # parameterValues = {}
#       parameterValueType = "Alternative"
#       parameterValueSet = {
#         name   = "managedIdentityAuth"
#         values = {}
#       }
#       testLinks = []
#     }
#   })
# }

resource "azapi_resource" "api_connection_arm_access_policy" {
  type      = "Microsoft.Web/connections/accessPolicies@2016-06-01"
  parent_id = azurerm_api_connection.api_connection_arm.id
  name      = azurerm_logic_app_standard.logic_app.name
  location  = var.location
  body = jsonencode({
    principal = {
      type = "ActiveDirectory"
      identity = {
        tenantId = data.azurerm_client_config.current.tenant_id
        objectId = azurerm_logic_app_standard.logic_app.identity[0].principal_id
      }
    }
  })
  schema_validation_enabled = false
}
