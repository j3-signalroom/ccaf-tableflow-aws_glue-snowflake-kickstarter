# Create the Snowflake user RSA keys pairs
module "snowflake_user_rsa_key_pairs_rotation" {   
  source  = "github.com/j3-signalroom/iac-snowflake-user-rsa_key_pairs_rotation-tf_module"

  # Required Input(s)
  aws_region                = var.aws_region
  aws_account_id            = data.aws_caller_identity.current.account_id
  snowflake_account         = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"]
  service_account_user      = local.secrets_insert

  # Optional Input(s)
  secret_insert             = local.secrets_insert
  day_count                 = var.day_count
  aws_lambda_memory_size    = var.aws_lambda_memory_size
  aws_lambda_timeout        = var.aws_lambda_timeout
  aws_log_retention_in_days = var.aws_log_retention_in_days
}

provider "snowflake" {
  role              = "SYSADMIN"
  organization_name = local.snowflake_organization_name
  account_name      = local.snowflake_account_name
  user              = local.snowflake_admin_user
  authenticator     = local.snowflake_authenticator
  private_key       = local.snowflake_active_private_key

  # Enable preview features
  preview_features_enabled = [
    "snowflake_stage_resource",
    "snowflake_external_table_resource",
    "snowflake_file_format_resource"
  ]
}

provider "snowflake" {
  alias             = "security_admin"
  role              = "SECURITYADMIN"
  organization_name = local.snowflake_organization_name
  account_name      = local.snowflake_account_name
  user              = local.snowflake_admin_user
  authenticator     = local.snowflake_authenticator
  private_key       = local.snowflake_active_private_key
}

provider "snowflake" {
  alias             = "account_admin"
  role              = "ACCOUNTADMIN"
  organization_name = local.snowflake_organization_name
  account_name      = local.snowflake_account_name
  user              = local.snowflake_admin_user
  authenticator     = local.snowflake_authenticator
  private_key       = local.snowflake_active_private_key

  # Enable preview features
  preview_features_enabled = [
    "snowflake_storage_integration_resource",
    "snowflake_stage_resource",
    "snowflake_external_table_resource",
    "snowflake_file_format_resource"
  ]
}

module "snowflake_glue_s3_access_role" {
  source                      = "./modules/snowflake_glue_s3_access_role"
  s3_bucket_arn               = aws_s3_bucket.iceberg_bucket.arn
  snowflake_glue_s3_role_name = local.snowflake_aws_role_name
  snowflake_aws_role_arn      = local.snowflake_aws_role_arn
  aws_s3_integration_name     = local.aws_s3_integration_name
  base_path                   = local.base_path
  organization_name           = local.snowflake_organization_name
  account_name                = local.snowflake_account_name
  admin_user                  = local.snowflake_admin_user
  authenticator               = local.snowflake_authenticator
  active_private_key          = local.snowflake_active_private_key
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

  # Setting the attributes to `null`, effectively unsets the attribute.  Refer to the 
  # `https://docs.snowflake.com/en/user-guide/key-pair-auth#configuring-key-pair-rotation`
  # for more information
  rsa_public_key    = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 1 ? jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_1"] : null
  rsa_public_key_2  = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 2 ? jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_2"] : null

  depends_on = [ 
    snowflake_account_role.security_admin_role,
    module.snowflake_user_rsa_key_pairs_rotation
  ]
}

resource "snowflake_account_role" "account_admin_role" {
  provider = snowflake.account_admin
  name     = local.account_admin_role
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

resource "snowflake_grant_privileges_to_account_role" "schema" {
  provider          = snowflake
  privileges        = ["CREATE STAGE", "CREATE FILE FORMAT", "CREATE EXTERNAL TABLE", "USAGE"]
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

resource "snowflake_grant_privileges_to_account_role" "database" {
  provider          = snowflake
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

resource "snowflake_grant_privileges_to_account_role" "integration_grant" {
  provider          = snowflake
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_account_object {
    object_type = "INTEGRATION"
    object_name = local.aws_s3_integration_name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role,
    module.snowflake_glue_s3_access_role
  ]
}

resource "snowflake_grant_account_role" "user_account_admin" {
  provider  = snowflake
  role_name = snowflake_account_role.account_admin_role.name
  user_name = snowflake_user.user.name
  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role 
  ]
}

resource "snowflake_grant_privileges_to_account_role" "file_format_usage" {
  provider          = snowflake
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_schema_object {
    object_type = "FILE FORMAT"
    object_name = "${snowflake_database.tableflow.name}.${snowflake_schema.tableflow.name}.${snowflake_file_format.parquet.name}"
  }

  depends_on = [
    snowflake_file_format.parquet,
    snowflake_account_role.account_admin_role
  ]
}

# GRANT USAGE ON STAGE <stage_name> TO ROLE <account_admin_role>;
resource "snowflake_grant_privileges_to_account_role" "stage_usage" {
  provider          = snowflake
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_schema_object {
    object_type = "STAGE"
    object_name = "${snowflake_database.tableflow.name}.${snowflake_schema.tableflow.name}.${snowflake_stage.stock_trades.name}"
  }

  depends_on = [
    snowflake_stage.stock_trades,
    snowflake_account_role.account_admin_role
  ]
}
