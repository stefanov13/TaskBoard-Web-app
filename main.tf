terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Generate a random integer to create a globally unique name
resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group_name}${random_integer.ri.result}" # TaskBoardRG
  location = var.resource_group_location                             # "West Europe"
}

# Create the Linux App Service Plan
resource "azurerm_service_plan" "asp" {
  name                = "${var.app_service_name}${random_integer.ri.result}" # "task-board-${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1"
}

# Create the web app, pass in the App Service Plan ID
resource "azurerm_linux_web_app" "webapp" {
  name                = "${var.app_service_plan_name}${random_integer.ri.result}" # "task-board-plan-${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.asp.location
  service_plan_id     = azurerm_service_plan.asp.id
  connection_string {
    name = "DefaultConnection"
    type = "SQLAzure"
    value = "Data Source=tcp:${
      azurerm_mssql_server.amssqls.fully_qualified_domain_name
      },1433;Initial Catalog=${
      azurerm_mssql_firewall_rule.mssqlfw.name
      };User ID=${
      "4dm1n157r470r"
      };Password=${
      "4-v3ry-53cr37-p455w0rd"
    };Trusted_Connection=False; MultipleActiveResultSets=True;"

  }

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }
}

# Deploy code from a public GitHub repo
resource "azurerm_app_service_source_control" "assc" {
  app_id                 = azurerm_linux_web_app.webapp.id
  repo_url               = var.repo_URL # "https://github.com/stefanov13/TaskBoard-Web-app.git"
  branch                 = "main"
  use_manual_integration = true
}

# Create MSSQL server instance
resource "azurerm_mssql_server" "amssqls" {
  name                         = "${var.sql_server_name}${random_integer.ri.result}" # "taskboard-sql-${random_integer.ri.result}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login    # "4dm1n157r470r"
  administrator_login_password = var.sql_admin_password # "4-v3ry-53cr37-p455w0rd"
}

# Create MSSQL DataBase
resource "azurerm_mssql_database" "amssqldb" {
  name         = "${var.sql_database_name}${random_integer.ri.result}" # "task-board-mssql-db-${random_integer.ri.result}"
  server_id    = azurerm_mssql_server.amssqls.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  sku_name     = "S0"
}

#Create MSSQL Firewall rule 
resource "azurerm_mssql_firewall_rule" "mssqlfw" {
  name             = "${var.firewall_rule_name}${random_integer.ri.result}" # "task-board-firewall-${random_integer.ri.result}"
  server_id        = azurerm_mssql_server.amssqls.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}
