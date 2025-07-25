data "aws_caller_identity" "current" {}

locals {
  snowflake_organization_name   = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[0]}"
  snowflake_account_name        = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[1]}"
  snowflake_admin_user          = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["admin_user"]
  snowflake_active_private_key  = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["active_rsa_public_key_number"] == 1 ? data.aws_secretsmanager_secret_version.admin_private_key_1.secret_string : data.aws_secretsmanager_secret_version.admin_private_key_2.secret_string
  snowflake_authenticator       = "SNOWFLAKE_JWT"
  cloud                         = "AWS"
  secrets_insert                = "tableflow_kickstarter"
  catalog_integration_name       = "${local.secrets_insert}_catalog_integration"
  confluent_secrets_path_prefix = "/confluent_cloud_resource/${local.secrets_insert}"
  snowflake_secrets_path_prefix = "/snowflake_resource/${local.secrets_insert}"
  snowflake_aws_role_name       = "snowflake_glue_s3_role"
  snowflake_aws_role_arn        = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.snowflake_aws_role_name}"
  volume_name                   = "${upper(local.secrets_insert)}_VOLUME"
  user_name                     = "${upper(local.secrets_insert)}"
  warehouse_name                = "${upper(local.secrets_insert)}"
  database_name                 = "${upper(local.secrets_insert)}"
  schema_name                   = "${upper(local.secrets_insert)}"
  security_admin_role           = "${local.user_name}_SECURITY_ADMIN_ROLE"
  system_admin_role             = "${local.user_name}_SYSTEM_ADMIN_ROLE"
  tableflow_glue_s3_role_name   = "tableflow_glue_s3_role"
  tableflow_glue_s3_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.tableflow_glue_s3_role_name}"
  service_account_name          = "${local.secrets_insert}_flink_sql_statements_runner"
  flink_rest_endpoint           = "https://flink.${var.aws_region}.${lower(local.cloud)}.confluent.cloud"
  account_identifier            = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"]
}