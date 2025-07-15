resource "snowflake_warehouse" "tableflow_kickstarter" {
  name           = local.warehouse_name
  warehouse_size = "xsmall"
  auto_suspend   = 60
  provider       = snowflake
}

resource "snowflake_database" "tableflow_kickstarter" {
  name     = local.database_name
  provider = snowflake
  comment  = "Database for Tableflow Kafka Topic data"

  depends_on = [ 
    snowflake_warehouse.tableflow_kickstarter 
  ]
}

resource "snowflake_schema" "tableflow_kickstarter" {
  name       = local.schema_name
  database   = local.database_name
  provider   = snowflake
  comment    = "Schema for Tableflow Kafka Topic data"

  depends_on = [
    snowflake_database.tableflow_kickstarter
  ]
}
locals {
  snowflake_active_public_key_jwt = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 1  ? jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["public_key_1_jwt"] : jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["public_key_2_jwt"]
}

data "http" "catalog_integration" {
  url    = "https://${local.snowflake_account_name}.snowflakecomputing.com/api/v2/statements"
  method = "POST"

  request_headers = {
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer ${local.snowflake_active_public_key_jwt}"
    "Accept"        = "application/json"
    "User-Agent"    = "Terraform-Snowflake-RSA"
  }

  request_body = jsonencode({
    statement = "CREATE OR REPLACE CATALOG INTEGRATION IF NOT EXISTS ${local.secrets_insert}_catalog_integration CATALOG_SOURCE = GLUE TABLE_FORMAT = ICEBERG ENABLED = TRUE CATALOG_NAMESPACE =  ${local.secrets_insert}_catalog_namespace GLUE_AWS_ROLE_ARN = '${local.snowflake_aws_role_arn}' GLUE_REGION = '${var.aws_region}' GLUE_CATALOG_ID = 'glue_catalog_id'"
    
    timeout   = 60
    warehouse = local.warehouse_name
    database  = local.database_name
  })

  retry {
    attempts     = 5
    min_delay_ms = 5000
    max_delay_ms = 9000 
  }

  depends_on = [ 
    module.snowflake_user_rsa_key_pairs_rotation 
  ]
}

resource "null_resource" "after_catalog_integration" {
  triggers = {
    response = data.http.catalog_integration.response_body
  }
}
