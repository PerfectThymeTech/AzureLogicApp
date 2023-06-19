resource "azurerm_service_plan" "service_plan" {
  name                = "${local.prefix}-asp001"
  location            = var.location
  resource_group_name = azurerm_resource_group.app_rg.name
  tags                = var.tags

  maximum_elastic_worker_count = 20
  os_type                      = "Windows"
  per_site_scaling_enabled     = false
  sku_name                     = "WS1"
  worker_count                 = 3
  zone_balancing_enabled       = true
}

resource "azurerm_logic_app_standard" "logic_app" {
  name                = "${local.prefix}-la001"
  location            = var.location
  resource_group_name = azurerm_resource_group.app_rg.name
  tags                = var.tags
  identity {
    type = "SystemAssigned"
  }

  app_service_plan_id        = azurerm_service_plan.service_plan.id
  bundle_version             = "[1.*, 2.0.0)"
  client_affinity_enabled    = false
  client_certificate_mode    = "Required"
  enabled                    = true
  https_only                 = true
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key
  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_share_name = azapi_resource.storage_file_share.name
  use_extension_bundle       = true
  version                    = "~4"
  virtual_network_subnet_id  = azapi_resource.subnet_logic_app.id
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.application_insights.instrumentation_key
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.application_insights.connection_string
    "FUNCTIONS_WORKER_RUNTIME"              = "node"
    "WEBSITE_NODE_DEFAULT_VERSION"          = "~18"
    "WEBSITE_CONTENTOVERVNET"               = "1"
  }
  site_config {
    always_on       = false
    app_scale_limit = 0
    # cors {
    #   allowed_origins = []
    #   support_credentials = false
    # }
    # health_check_path = ""
    dotnet_framework_version         = "v6.0"
    elastic_instance_minimum         = 3
    ftps_state                       = "Disabled"
    http2_enabled                    = true
    ip_restriction                   = []
    min_tls_version                  = "1.2"
    pre_warmed_instance_count        = 1
    runtime_scale_monitoring_enabled = true
    scm_ip_restriction               = []
    scm_min_tls_version              = "1.2"
    scm_type                         = "None"
    scm_use_main_ip_restriction      = false
    use_32_bit_worker_process        = false
    vnet_route_all_enabled           = true
    websockets_enabled               = false
  }
}

data "azurerm_monitor_diagnostic_categories" "diagnostic_categories_logic_app" {
  resource_id = azurerm_logic_app_standard.logic_app.id
}

resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_logic_app" {
  name                       = "logAnalytics"
  target_resource_id         = azurerm_logic_app_standard.logic_app.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics_workspace.id

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_logic_app.log_category_groups
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
    for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_logic_app.metrics
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

resource "azurerm_private_endpoint" "logic_app_private_endpoint" {
  name                = "${azurerm_logic_app_standard.logic_app.name}-pe"
  location            = var.location
  resource_group_name = azurerm_resource_group.app_rg.name
  tags                = var.tags

  custom_network_interface_name = "${azurerm_logic_app_standard.logic_app.name}-nic"
  private_service_connection {
    name                           = "${azurerm_logic_app_standard.logic_app.name}-pe"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_logic_app_standard.logic_app.id
    subresource_names              = ["sites"]
  }
  subnet_id = azapi_resource.subnet_services.id
  private_dns_zone_group {
    name = "${azurerm_logic_app_standard.logic_app.name}-arecord"
    private_dns_zone_ids = [
      var.private_dns_zone_id_sites
    ]
  }
}
