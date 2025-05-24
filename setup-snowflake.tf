# Create the Snowflake user RSA keys pairs
module "snowflake_user_rsa_key_pairs_rotation" {   
    source  = "github.com/j3-signalroom/iac-snowflake-user-rsa_key_pairs_rotation-tf_module"

    # Required Input(s)
    aws_region                = var.aws_region
    aws_account_id            = var.aws_account_id
    snowflake_account         = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"]
    service_account_user      = local.secrets_insert

    # Optional Input(s)
    secret_insert             = local.secrets_insert
    day_count                 = var.day_count
    aws_lambda_memory_size    = var.aws_lambda_memory_size
    aws_lambda_timeout        = var.aws_lambda_timeout
    aws_log_retention_in_days = var.aws_log_retention_in_days
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
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.admin_user
  authenticator     = local.authenticator
  private_key       = local.active_private_key

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
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.admin_user
  authenticator     = local.authenticator
  private_key       = local.active_private_key
}

resource "snowflake_account_role" "security_admin_role" {
  provider = snowflake.security_admin
  name     = "${upper(local.secrets_insert)}_ROLE"
}

resource "snowflake_user" "user" {
  provider          = snowflake.security_admin
  name              = local.user_name
  default_warehouse = local.warehouse_name
  default_role      = snowflake_account_role.security_admin_role.name
  default_namespace = "${local.database_name}.${local.schema_name}"

  # Setting the attributes to `null`, effectively unsets the attribute
  # Refer to this link `https://docs.snowflake.com/en/user-guide/key-pair-auth#configuring-key-pair-rotation`
  # for more information
  rsa_public_key    = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 1 ? local.rsa_public_key_1 : null
  rsa_public_key_2  = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 2 ? local.rsa_public_key_2 : null

  depends_on = [ 
    snowflake_account_role.security_admin_role
  ]
}

provider "snowflake" {
  alias             = "account_admin"
  role              = "ACCOUNTADMIN"
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.admin_user
  authenticator     = local.authenticator
  private_key       = local.active_private_key

  # Enable preview features
  preview_features_enabled = [
    "snowflake_storage_integration_resource"
  ]
}

resource "snowflake_account_role" "account_admin_role" {
  provider = snowflake.account_admin
  name     = "${local.user_name}_ADMIN_ROLE"
}

resource "snowflake_grant_privileges_to_account_role" "user" {
  provider          = snowflake.security_admin
  privileges        = ["MONITOR"]
  account_role_name = snowflake_account_role.security_admin_role.name  
  on_account_object {
    object_type = "USER"
    object_name = local.user_name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.security_admin_role 
  ]
}

resource "snowflake_grant_account_role" "user_security_admin" {
  provider  = snowflake.security_admin
  role_name = snowflake_account_role.security_admin_role.name
  user_name = local.user_name

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.security_admin_role 
  ]
}

resource "snowflake_warehouse" "tableflow" {
  name           = local.warehouse_name
  warehouse_size = "xsmall"
  auto_suspend   = 60
  provider       = snowflake
}

resource "snowflake_grant_privileges_to_account_role" "warehouse" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.security_admin_role.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = local.warehouse_name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.security_admin_role,
    snowflake_warehouse.tableflow
  ]
}

resource "snowflake_database" "tableflow" {
  name     = local.database_name
  provider = snowflake
}

resource "snowflake_grant_privileges_to_account_role" "database" {
  provider          = snowflake.account_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.tableflow.name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role,
    snowflake_warehouse.tableflow,
    snowflake_database.tableflow
  ]
}

resource "snowflake_schema" "tableflow" {
  name       = local.schema_name
  database   = snowflake_database.tableflow.name
  provider   = snowflake
}

resource "snowflake_grant_privileges_to_account_role" "schema" {
  provider          = snowflake.account_admin
  privileges        = ["CREATE FILE FORMAT", "USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_schema {
    schema_name = "${local.database_name}.${local.schema_name}"
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role,
    snowflake_warehouse.tableflow,
    snowflake_database.tableflow,
    snowflake_schema.tableflow
  ]
}

data "external" "topic_table_path" {
  program = ["python3", "${path.module}/topic_table_path.py"]

  query = {
    kafka_topic_name = confluent_kafka_topic.stock_trades.topic_name
    kafka_cluster_id = confluent_kafka_cluster.kafka_cluster.id
    environment_id = confluent_environment.tableflow_kickstarter.id
    tableflow_api_key = module.tableflow_api_key.active_api_key.id
    tableflow_api_secret = module.tableflow_api_key.active_api_key.secret
  }
}

resource "snowflake_storage_integration" "aws_s3_integration" {
  provider                  = snowflake.account_admin
  name                      = local.aws_s3_integration_name
  storage_allowed_locations = ["${data.external.topic_table_path.result["base_path"]}"]
  storage_provider          = "S3"
  storage_aws_object_acl    = "bucket-owner-full-control"
  storage_aws_role_arn      = local.snowflake_aws_role_arn
  enabled                   = true
  type                      = "EXTERNAL_STAGE"

  depends_on = [
    module.glue_s3_access_role
  ]
}
resource "snowflake_grant_privileges_to_account_role" "integration_grant" {
  provider          = snowflake.account_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_account_object {
    object_type = "INTEGRATION"
    object_name = local.aws_s3_integration_name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role,
    snowflake_storage_integration.aws_s3_integration
  ]
}

resource "snowflake_grant_account_role" "user_account_admin" {
  provider  = snowflake.account_admin
  role_name = snowflake_account_role.account_admin_role.name
  user_name = snowflake_user.user.name
  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role 
  ]
}

resource "snowflake_stage" "stock_trades" {
  provider            = snowflake
  name                = upper("stock_trades_stage")
  url                 = "${data.external.topic_table_path.result["table_path"]}/data/"
  database            = local.database_name
  schema              = local.schema_name 
  storage_integration = local.aws_s3_integration_name

  depends_on = [
    snowflake_schema.tableflow,
    snowflake_storage_integration.aws_s3_integration,
    module.snowflake_s3_access_role 
  ]
}

resource "snowflake_external_table" "stock_trades" {
  provider    = snowflake
  database    = local.database_name
  schema      = local.schema_name
  name        = upper("stock_trades")
  file_format = "TYPE = 'PARQUET'"
  location    = "@${local.database_name}.${local.schema_name}.${snowflake_stage.stock_trades.name}"
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
}
