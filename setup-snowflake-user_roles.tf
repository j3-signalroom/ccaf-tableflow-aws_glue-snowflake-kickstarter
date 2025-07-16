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

data "aws_secretsmanager_secret" "svc_public_keys" {
  name = local.snowflake_secrets_path_prefix

  depends_on = [ 
    module.snowflake_user_rsa_key_pairs_rotation 
  ]
}

data "aws_secretsmanager_secret_version" "svc_public_keys" {
  secret_id = data.aws_secretsmanager_secret.svc_public_keys.id
}

# Create the Snowflake user RSA keys pairs
module "snowflake_user_rsa_key_pairs_rotation" {   
  source  = "github.com/j3-signalroom/iac-snowflake-user-rsa_key_pairs_rotation-tf_module"

  # Required Input(s)
  aws_region                = var.aws_region
  snowflake_account         = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"]
  service_account_user      = local.secrets_insert

  # Optional Input(s)
  secret_insert             = local.secrets_insert
  day_count                 = var.day_count
  aws_lambda_memory_size    = var.aws_lambda_memory_size
  aws_lambda_timeout        = var.aws_lambda_timeout
  aws_log_retention_in_days = var.aws_log_retention_in_days
}

module "snowflake_aws_glue_s3_access" {
  source                       = "./modules/snowflake_aws_glue_s3_access"
  s3_bucket_arn                = aws_s3_bucket.iceberg_bucket.arn
  snowflake_role_name          = local.snowflake_aws_role_name
  catalog_integration_name     = ""
  security_admin_role_name     = local.security_admin_role
  snowflake_aws_role_arn       = local.snowflake_aws_role_arn
  volume_name                  = local.volume_name
  tableflow_topic_s3_base_path = local.tableflow_topic_s3_base_path
  organization_name            = local.snowflake_organization_name
  account_name                 = local.snowflake_account_name
  admin_user                   = local.snowflake_admin_user
  authenticator                = local.snowflake_authenticator
  active_private_key           = local.snowflake_active_private_key
  kafka_cluster_id             = confluent_kafka_cluster.kafka_cluster.id
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
  rsa_public_key    = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 1 ? jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_1"] : null
  rsa_public_key_2  = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 2 ? jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_2"] : null
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
