data "aws_caller_identity" "current" {}

data "aws_secretsmanager_secret" "admin_user" {
  name = var.admin_user_secrets_root_path
}

data "aws_secretsmanager_secret_version" "admin_user" {
  secret_id = data.aws_secretsmanager_secret.admin_user.id
}

locals {
  snowflake_account_identifier  = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_account_identifier"]
  snowflake_organization_name   = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_organization_name"]
  snowflake_account_name        = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_account_name"]
  snowflake_admin_user          = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["new_admin_user"]
  snowflake_active_private_key  = base64decode(jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["active_key_number"] == 1 ? jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_rsa_private_key_1_pem"] : jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_rsa_private_key_2_pem"])
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
  aws_s3_integration_name       = "${upper(local.secrets_insert)}_STORAGE_INTEGRATION"
  stage_name                    = "${upper(local.secrets_insert)}_STAGE"
  security_admin_role           = "${local.user_name}_SECURITY_ADMIN_ROLE"
  system_admin_role             = "${local.user_name}_SYSTEM_ADMIN_ROLE"
  tableflow_glue_s3_role_name   = "tableflow_glue_s3_role"
  tableflow_glue_s3_role_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.tableflow_glue_s3_role_name}"
  service_account_name          = "${local.secrets_insert}_flink_sql_statements_runner"
  flink_rest_endpoint           = "https://flink.${var.aws_region}.${lower(local.cloud)}.confluent.cloud"
}