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

data "confluent_organization" "signalroom" {}

data "aws_caller_identity" "current" {}

locals {
  organization_name             = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[0]}"
  account_name                  = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[1]}"
  admin_user                    = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["admin_user"]
  active_private_key            = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["active_rsa_public_key_number"] == 1 ? data.aws_secretsmanager_secret_version.admin_private_key_1.secret_string : data.aws_secretsmanager_secret_version.admin_private_key_2.secret_string
  authenticator                 = "SNOWFLAKE_JWT"
  cloud                         = "AWS"
  secrets_insert                = "tableflow_kickstarter"
  confluent_secrets_path_prefix = "/confluent_cloud_resource/${local.secrets_insert}"
  snowflake_secrets_path_prefix = "/snowflake_resource/${local.secrets_insert}"
  snowflake_aws_role_name       = "snowflake_s3_role"
  snowflake_aws_role_arn        = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.snowflake_aws_role_name}"
  aws_s3_integration_name       = "${upper(local.secrets_insert)}_STORAGE_INTEGRATION"
  user_name                     = "${upper(local.secrets_insert)}"
  warehouse_name                = "${upper(local.secrets_insert)}"
  database_name                 = "${upper(local.secrets_insert)}"
  schema_name                   = "${upper(local.secrets_insert)}"
  account_admin_role            = "${local.user_name}_ADMIN_ROLE"
  tableflow_glue_s3_role_name   = "tableflow_glue_s3_role"
  tableflow_glue_s3_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.tableflow_glue_s3_role_name}"
}