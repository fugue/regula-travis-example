# EXAMPLE VULNERABLE TERRAFORM FOR LEARNING PURPOSES ONLY
# Intentionally opens port 22 to the internet!

provider "azurerm" {
  features {}
}

# Random string to generate a unique storage account name
resource "random_string" "seed" {
  length = 16
  special = false
  number = false
  upper = false
}

resource "azurerm_resource_group" "main" {
  name     = "${random_string.seed.result}-rg"
  location = "eastus2"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_security_group" "devnsg" {
  name                = "dev-nsg"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  # Port 22 is open to the world. Don't do this in real life!
  security_rule {
    name                        = "dev-nsg-rule"
    priority                    = 100
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_ranges     = ["22"]
    source_address_prefixes     = ["0.0.0.0/0"]
    destination_address_prefix  = "*"
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "virtualNetwork1"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]

  subnet {
    name           = "subnet1"
    address_prefix = "10.0.1.0/24"
    security_group = azurerm_network_security_group.devnsg.id
  }

  subnet {
    name           = "subnet2"
    address_prefix = "10.0.2.0/24"
  }

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_watcher" "main" {
  name                = "${random_string.seed.result}-eastus2-watcher"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law${random_string.seed.result}"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  sku                 = "PerGB2018"

  tags = {
    environment = "dev"
  }
}

resource "azurerm_network_watcher_flow_log" "main" {
  network_watcher_name = "${azurerm_network_watcher.main.name}"
  resource_group_name  = "${azurerm_resource_group.main.name}"

  network_security_group_id = "${azurerm_network_security_group.devnsg.id}"
  storage_account_id        = "${azurerm_storage_account.main.id}"
  enabled                   = true

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = false
    workspace_id          = "${azurerm_log_analytics_workspace.main.workspace_id}"
    workspace_region      = "${azurerm_log_analytics_workspace.main.location}"
    workspace_resource_id = "${azurerm_log_analytics_workspace.main.id}"
    interval_in_minutes   = 10
  }

  tags = {
    environment = "dev"
  }
}

# Storage account to hold the flow logs
resource "azurerm_storage_account" "main" {
  name                = "sa${random_string.seed.result}"
  resource_group_name = "${azurerm_resource_group.main.name}"
  location            = "${azurerm_resource_group.main.location}"

  account_tier              = "Standard"
  account_kind              = "StorageV2"
  account_replication_type  = "LRS"
  enable_https_traffic_only = true

  network_rules {
    default_action = "Deny"
    bypass = ["Logging", "Metrics", "AzureServices"]
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  queue_properties {
    logging {
      version = "1.0"
      read = true
      write = true
      delete = true
      retention_policy_days = 10
    }

    hour_metrics {
      enabled               = true
      include_apis          = true
      version               = "1.0"
      retention_policy_days = 10
    }

    minute_metrics {
      enabled               = true
      include_apis          = true
      version               = "1.0"
      retention_policy_days = 10
    }
  }

  tags = {
    environment = "dev"
  }
}