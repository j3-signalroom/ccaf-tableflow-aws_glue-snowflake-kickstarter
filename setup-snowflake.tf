module "snowflake_user_privileges" {
  source                         = "./snowflake_user_privileges_tf_module"
  snowflake_secrets_path_prefix  = local.snowflake_secrets_path_prefix
  secrets_insert                 = local.secrets_insert
  user_name                      = upper(local.secrets_insert)
  warehouse_name                 = upper(local.secrets_insert)
  database_name                  = upper(local.secrets_insert)
  schema_name                    = upper(local.secrets_insert)
  aws_s3_integration_name        = "${upper(local.secrets_insert)}_STORAGE_INTEGRATION"
  aws_region                     = var.aws_region
  aws_account_id                 = var.aws_account_id
  day_count                      = var.day_count
  aws_lambda_memory_size         = var.aws_lambda_memory_size
  aws_lambda_timeout             = var.aws_lambda_timeout
  aws_log_retention_in_days      = var.aws_log_retention_in_days
}

module "glue_s3_access_role" {
  source                          = "./glue_s3_access_role_tf_module"
  s3_bucket_arn                   = aws_s3_bucket.iceberg_bucket.arn
}

module "snowflake_s3_access_role" {
  source                          = "./snowflake_s3_access_role_tf_module"
  s3_bucket_arn                   = aws_s3_bucket.iceberg_bucket.arn
  storage_integration_role_arn    = snowflake_storage_integration.aws_s3_integration.storage_aws_iam_user_arn
  storage_integration_external_id = snowflake_storage_integration.aws_s3_integration.storage_aws_external_id
}

provider "snowflake" {
  role              = "SYSADMIN"
  organization_name = module.snowflake_user_privileges.provider_organization_name
  account_name      = module.snowflake_user_privileges.provider_account_name
  user              = module.snowflake_user_privileges.provider_user_name
  authenticator     = module.snowflake_user_privileges.provider_authenticator
  private_key       = module.snowflake_user_privileges.provider_private_key

  # Enable preview features
  preview_features_enabled = [
    "snowflake_file_format_resource",
    "snowflake_stage_resource",
    "snowflake_external_table_resource"
  ]
}

provider "snowflake" {
  alias             = "security_admin"
  role              = "SECURITYADMIN"
  organization_name = module.snowflake_user_privileges.provider_organization_name
  account_name      = module.snowflake_user_privileges.provider_account_name
  user              = module.snowflake_user_privileges.provider_user_name
  authenticator     = module.snowflake_user_privileges.provider_authenticator
  private_key       = module.snowflake_user_privileges.provider_private_key
}

provider "snowflake" {
  alias             = "account_admin"
  role              = "ACCOUNTADMIN"
  organization_name = module.snowflake_user_privileges.provider_organization_name
  account_name      = module.snowflake_user_privileges.provider_account_name
  user              = module.snowflake_user_privileges.provider_user_name
  authenticator     = module.snowflake_user_privileges.provider_authenticator
  private_key       = module.snowflake_user_privileges.provider_private_key

  # Enable preview features
  preview_features_enabled = [
    "snowflake_storage_integration_resource"
  ]
}

resource "snowflake_warehouse" "tableflow" {
  name           = upper(local.secrets_insert)
  warehouse_size = "xsmall"
  auto_suspend   = 60
  provider       = snowflake

  depends_on = [ module.snowflake_user_privileges ]
}

resource "snowflake_database" "tableflow" {
  name     = upper(local.secrets_insert)
  provider = snowflake

  depends_on = [ snowflake_warehouse.tableflow ]
}

resource "snowflake_schema" "tableflow" {
  name       = upper(local.secrets_insert)
  database   = snowflake_database.tableflow.name
  provider   = snowflake

  depends_on = [
    snowflake_database.tableflow
  ]
}

locals {
  base_path = "s3://${local.secrets_insert}/10010010/10110010/${data.confluent_organization.signalroom.id}/${confluent_environment.tableflow_kickstarter.id}/${confluent_kafka_cluster.kafka_cluster.id}/v1/"
}

resource "snowflake_storage_integration" "aws_s3_integration" {
  provider                  = snowflake.account_admin
  name                      = module.snowflake_user_privileges.aws_s3_integration_name
  storage_allowed_locations = ["${local.base_path}"]
  storage_provider          = "S3"
  storage_aws_object_acl    = "bucket-owner-full-control"
  storage_aws_role_arn      = local.snowflake_aws_role_arn
  enabled                   = true
  type                      = "EXTERNAL_STAGE"

  depends_on = [
    module.glue_s3_access_role
  ]
}

resource "snowflake_stage" "stock_trades" {
  provider            = snowflake
  name                = upper("stock_trades_stage")
  url                 = "${local.base_path}/${confluent_tableflow_topic.stock_trades.id}/data/"
  database            = module.snowflake_user_privileges.database_name
  schema              = module.snowflake_user_privileges.schema_name 
  storage_integration = module.snowflake_user_privileges.aws_s3_integration_name

  depends_on = [ 
    snowflake_storage_integration.aws_s3_integration,
    module.snowflake_s3_access_role 
  ]
}

resource "snowflake_external_table" "stock_trades" {
  provider    = snowflake
  database    = module.snowflake_user_privileges.database_name
  schema      = module.snowflake_user_privileges.schema_name
  name        = upper("stock_trades")
  file_format = "TYPE = 'PARQUET'"
  location    = "@${module.snowflake_user_privileges.database_name}.${module.snowflake_user_privileges.schema_name}.${snowflake_stage.stock_trades.name}"
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
