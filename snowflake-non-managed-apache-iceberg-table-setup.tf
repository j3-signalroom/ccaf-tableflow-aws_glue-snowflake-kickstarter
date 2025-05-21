provider "snowflake" {
  role              = "SYSADMIN"
  organization_name = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[0]}"
  account_name      = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[1]}"
  user              = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["admin_user"]
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["active_rsa_public_key_number"] == 1 ? data.aws_secretsmanager_secret_version.admin_private_key_1.secret_string : data.aws_secretsmanager_secret_version.admin_private_key_2.secret_string

  # Enable preview features
  preview_features_enabled = [
    "snowflake_file_format_resource",
    "snowflake_stage_resource",
    "snowflake_external_table_resource"
  ]
}

resource "snowflake_warehouse" "tableflow" {
  name           = upper(local.secrets_insert)
  warehouse_size = "xsmall"
  auto_suspend   = 60
  provider       = snowflake
}

resource "snowflake_database" "tableflow" {
  name     = upper(local.secrets_insert)
  provider = snowflake
}

resource "snowflake_schema" "tableflow" {
  name       = upper(local.secrets_insert)
  database   = snowflake_database.tableflow.name
  provider   = snowflake

  depends_on = [
    snowflake_database.tableflow
  ]
}

resource "snowflake_storage_integration" "aws_s3_integration" {
  provider                  = snowflake.account_admin
  name                      = "AWS_S3_STORAGE_INTEGRATION"
  storage_allowed_locations = ["s3://${local.secrets_insert}/warehouse/"]
  storage_provider          = "S3"
  storage_aws_object_acl    = "bucket-owner-full-control"
  storage_aws_role_arn      = local.snowflake_aws_role_arn
  enabled                   = true
  type                      = "EXTERNAL_STAGE"

  depends_on = [ 
    module.snowflake_s3_access_role 
  ]
}

resource "snowflake_stage" "stock_trades" {
  name                = upper("stock_trades_stage")
  url                 = "s3://${local.secrets_insert}/warehouse/trades.db/stock_trades/data/"
  database            = snowflake_database.tableflow.name
  schema              = snowflake_schema.tableflow.name
  storage_integration = snowflake_storage_integration.aws_s3_integration.name
  provider            = snowflake

  depends_on = [ 
    snowflake_storage_integration.aws_s3_integration 
  ]
}

resource "snowflake_external_table" "stock_trades" {
  provider    = snowflake
  database    = snowflake_database.tableflow.name
  schema      = snowflake_schema.tableflow.name
  name        = upper("stock_trades")
  file_format = "TYPE = 'PARQUET'"
  location    = "@${snowflake_database.tableflow.name}.${snowflake_schema.tableflow.name}.${snowflake_stage.stock_trades.name}"
  auto_refresh = true

  column {
    as   = "(value:side::string)"
    name = "side"
    type = "VARCHAR"
  }

  column {
    as   = "(value:quantity::bigint)"
    name = "quantity"
    type = "BIGINT"
  }

  column {
    as   = "(value:symbol::string)"
    name = "symbol"
    type = "VARCHAR"
  }

  column {
    as   = "(value:price::bigint)"
    name = "price"
    type = "BIGINT"
  }

  column {
    as   = "(value:account::string)"
    name = "account"
    type = "VARCHAR"
  }

  column {
    as   = "(value:userid::string)"
    name = "userid"
    type = "VARCHAR"
  }

  depends_on = [
    confluent_tableflow_topic.stock_trades,
    snowflake_stage.stock_trades
  ]
}

module "snowflake_s3_access_role" {
  source                          = "./snowflake_s3_access_role_tf_module"
  s3_bucket_arn                   = aws_s3_bucket.iceberg_bucket.arn
  storage_integration_role_arn    = snowflake_storage_integration.aws_s3_integration.storage_aws_iam_user_arn
  storage_integration_external_id = snowflake_storage_integration.aws_s3_integration.storage_aws_external_id
}