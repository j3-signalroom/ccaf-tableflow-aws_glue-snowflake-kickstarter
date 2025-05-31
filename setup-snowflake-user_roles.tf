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

module "snowflake_glue_s3_access_role" {
  source                      = "./modules/snowflake_glue_s3_access_role"
  s3_bucket_arn               = aws_s3_bucket.iceberg_bucket.arn
  snowflake_glue_s3_role_name = local.snowflake_aws_role_name
  snowflake_aws_role_arn      = local.snowflake_aws_role_arn
  aws_s3_integration_name     = local.aws_s3_integration_name
  tableflow_topic_s3_base_path                   = local.tableflow_topic_s3_base_path
  organization_name           = local.snowflake_organization_name
  account_name                = local.snowflake_account_name
  admin_user                  = local.snowflake_admin_user
  authenticator               = local.snowflake_authenticator
  active_private_key          = local.snowflake_active_private_key
}

resource "snowflake_user" "user" {
  provider          = snowflake.security_admin
  name              = local.user_name
  default_warehouse = local.warehouse_name
  default_role      = local.system_admin_role
  default_namespace = "${local.database_name}.${local.schema_name}"

  # Setting the attributes to `null`, effectively unsets the attribute.  Refer to the 
  # `https://docs.snowflake.com/en/user-guide/key-pair-auth#configuring-key-pair-rotation`
  # for more information
  rsa_public_key    = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 1 ? jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_1"] : null
  rsa_public_key_2  = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 2 ? jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_2"] : null
}

resource "snowflake_account_role" "security_admin_role" {
  provider = snowflake.security_admin
  name     = local.security_admin_role
  comment  = "Security Admin role for ${local.user_name}"
}

resource "snowflake_grant_account_role" "user_security_admin" {
  provider  = snowflake.security_admin
  role_name = snowflake_account_role.security_admin_role.name
  user_name = snowflake_user.user.name
  
  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.security_admin_role 
  ]
}

resource "snowflake_account_role" "system_admin_role" {
  provider = snowflake.security_admin
  name     = local.system_admin_role
  comment  = "System Admin role for ${local.user_name}"
}

resource "snowflake_grant_account_role" "user_system_admin" {
  provider  = snowflake.security_admin
  role_name = snowflake_account_role.system_admin_role.name
  user_name = snowflake_user.user.name
  
  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.system_admin_role 
  ]
}
