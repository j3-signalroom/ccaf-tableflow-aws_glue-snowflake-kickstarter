locals {
  rsa_public_key_1              = jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_1"]
  rsa_public_key_2              = jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_2"]
  organization_name             = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[0]}"
  account_name                  = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[1]}"
  admin_user                    = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["admin_user"]
  active_private_key            = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["active_rsa_public_key_number"] == 1 ? data.aws_secretsmanager_secret_version.admin_private_key_1.secret_string : data.aws_secretsmanager_secret_version.admin_private_key_2.secret_string
  authenticator                 = "SNOWFLAKE_JWT"
  cloud                         = "AWS"
  secrets_insert                = "tableflow_kickstarter"
  confluent_secrets_path_prefix = "/confluent_cloud_resource/${local.secrets_insert}"
  snowflake_secrets_path_prefix = "/snowflake_resource/${local.secrets_insert}"
  snowflake_aws_role_name       = "snowflake-role"
  snowflake_aws_role_arn        = "arn:aws:iam::${var.aws_account_id}:role/${local.snowflake_aws_role_name}"
  aws_s3_integration_name       = "${upper(local.secrets_insert)}_STORAGE_INTEGRATION"
  user_name                     = "${upper(local.secrets_insert)}"
  warehouse_name                = "${upper(local.secrets_insert)}"
  database_name                 = "${upper(local.secrets_insert)}"
  schema_name                   = "${upper(local.secrets_insert)}"
}
