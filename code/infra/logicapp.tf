resource "azurerm_service_plan" "service_plan" {
  name                = "${local.prefix}-asp001"
  location            = var.location
  resource_group_name = azurerm_resource_group.app_rg.name
  tags                = var.tags

  maximum_elastic_worker_count = 20
  os_type                  = "Windows"
  per_site_scaling_enabled = false
  sku_name                 = "WS1"
  worker_count             = 3
  zone_balancing_enabled   = true
}

resource "azurerm_logic_app_standard" "logic_app" {
  name = "${local.prefix}-la001"
  location = var.location
  resource_group_name = azurerm_resource_group.app_rg.name
  tags = var.tags
  identity {
    type = "SystemAssigned"
  }

  app_service_plan_id = azurerm_service_plan.service_plan.id
  bundle_version = "[1.*, 2.0.0)"
  client_affinity_enabled = false
  client_certificate_mode = "Required"
  enabled = true
  https_only = true
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key
  storage_account_name = azurerm_storage_account.storage.name
  storage_account_share_name = azapi_resource.storage_file_share.name
  use_extension_bundle = true
  version = "~4"
  virtual_network_subnet_id = azapi_resource.subnet_function.id
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
  }
  site_config {
    always_on = true
    app_scale_limit = 
    cors {
      allowed_origins = []
      support_credentials = false
    }
    dotnet_framework_version = 
  }
}

data "azurerm_monitor_diagnostic_categories" "diagnostic_categories_function" {
  resource_id = azapi_resource.function.id
}

resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_function" {
  name                       = "logAnalytics"
  target_resource_id         = azapi_resource.function.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_function.log_category_groups
    content {
      category_group = entry.value
      retention_policy {
        enabled = true
        days    = 30
      }
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_function.metrics
    content {
      category = entry.value
      enabled  = true
      retention_policy {
        enabled = true
        days    = 30
      }
    }
  }
}

resource "azurerm_private_endpoint" "function_private_endpoint" {
  name                = "${azapi_resource.function.name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.app_rg.name
  tags                = var.tags

  custom_network_interface_name = "${azapi_resource.function.name}-nic"
  private_service_connection {
    name                           = "${azapi_resource.function.name}-pe"
    is_manual_connection           = false
    private_connection_resource_id = azapi_resource.function.id
    subresource_names              = ["sites"]
  }
  subnet_id = azapi_resource.subnet_services.id
  private_dns_zone_group {
    name = "${azapi_resource.function.name}-arecord"
    private_dns_zone_ids = [
      var.private_dns_zone_id_sites
    ]
  }
}
