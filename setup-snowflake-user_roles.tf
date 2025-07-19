data "aws_secretsmanager_secret" "admin_public_keys" {
  name = "/snowflake_admin_credentials"
}

data "aws_secretsmanager_secret_version" "admin_public_keys" {
  secret_id = data.aws_secretsmanager_secret.admin_public_keys.id
}

data "aws_secretsmanager_secret" "admin_private_key_1" {
  name = "/snowflake_admin_credentials/rsa_private_key_pem_1"
}

data "aws_secretsmanager_secret_version" "admin_private_key_1" {
  secret_id = data.aws_secretsmanager_secret.admin_private_key_1.id
}

data "aws_secretsmanager_secret" "admin_private_key_2" {
  name = "/snowflake_admin_credentials/rsa_private_key_pem_2"
}

data "aws_secretsmanager_secret_version" "admin_private_key_2" {
  secret_id = data.aws_secretsmanager_secret.admin_private_key_2.id
}

locals {
  account_identifier = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"]
}

# Create the Snowflake user RSA keys pairs
module "snowflake_user_rsa_key_pairs_rotation" {   
  source  = "github.com/j3-signalroom/iac-snowflake-user-rsa_key_pairs_rotation-tf_module"

  # Required Input(s)
  aws_region                = var.aws_region
  account_identifier        = account_identifier
  service_account_user      = local.secrets_insert

  # Optional Input(s)
  secret_insert             = local.secrets_insert
  day_count                 = var.day_count
  aws_lambda_memory_size    = var.aws_lambda_memory_size
  aws_lambda_timeout        = var.aws_lambda_timeout
  aws_log_retention_in_days = var.aws_log_retention_in_days
}

# Emits CREATE USER <user_name> DEFAULT_WAREHOUSE = <warehouse_name> DEFAULT_ROLE = <system_admin_role> DEFAULT_NAMESPACE = <database_name>.<schema_name> RSA_PUBLIC_KEY = <rsa_public_key> RSA_PUBLIC_KEY_2 = NULL;
resource "snowflake_user" "user" {
  provider          = snowflake.security_admin
  name              = local.user_name
  default_warehouse = local.warehouse_name
  default_role      = local.system_admin_role
  default_namespace = "${local.database_name}.${local.schema_name}"

  # Setting the attributes to `null`, effectively unsets the attribute.  Refer to the 
  # `https://docs.snowflake.com/en/user-guide/key-pair-auth#configuring-key-pair-rotation`
  # for more information
  rsa_public_key    = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 1 ? module.snowflake_user_rsa_key_pairs_rotation.rsa_public_key_pem_1 : null
  rsa_public_key_2  = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 2 ? module.snowflake_user_rsa_key_pairs_rotation.rsa_public_key_pem_2 : null

  depends_on = [ 
    module.snowflake_user_rsa_key_pairs_rotation
  ]
}

locals {
  active_rsa_public_key_jwt    = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 1 ? module.snowflake_user_rsa_key_pairs_rotation.rsa_public_key_jwt_1 : module.snowflake_user_rsa_key_pairs_rotation.rsa_public_key_jwt_2
}

# Emits CREATE ROLE <security_admin_role> COMMENT = 'Security Admin role for <user_name>';
resource "snowflake_account_role" "security_admin_role" {
  provider = snowflake.security_admin
  name     = local.security_admin_role
  comment  = "Security Admin role for ${local.user_name}"
}

# Emits GRANT ROLE <security_admin_role> TO USER <user_name>;
resource "snowflake_grant_account_role" "user_security_admin" {
  provider  = snowflake.security_admin
  role_name = snowflake_account_role.security_admin_role.name
  user_name = snowflake_user.user.name
  
  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.security_admin_role 
  ]
}

# Emits CREATE ROLE <system_admin_role> COMMENT = 'System Admin role for <user_name>';
resource "snowflake_account_role" "system_admin_role" {
  provider = snowflake.security_admin
  name     = local.system_admin_role
  comment  = "System Admin role for ${local.user_name}"
}

# Emits GRANT ROLE <user_system_admin> TO USER <user_name>;
resource "snowflake_grant_account_role" "user_system_admin" {
  provider  = snowflake
  role_name = snowflake_account_role.system_admin_role.name
  user_name = snowflake_user.user.name
  
  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.system_admin_role 
  ]
}
