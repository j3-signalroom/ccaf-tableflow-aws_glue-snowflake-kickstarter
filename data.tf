data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_secretsmanager_secret" "admin_user" {
  name = var.admin_user_secrets_root_path
}

data "aws_secretsmanager_secret_version" "admin_user" {
  secret_id = data.aws_secretsmanager_secret.admin_user.id
}

locals {
  snowflake_account_identifier    = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_account_identifier"]
  snowflake_organization_name     = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_organization_name"]
  snowflake_account_name          = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_account_name"]
  snowflake_admin_user            = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["new_admin_user"]
  snowflake_active_private_key    = base64decode(jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["active_key_number"] == 1 ? jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_rsa_private_key_1_pem"] : jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_rsa_private_key_2_pem"])
  snowflake_authenticator         = "SNOWFLAKE_JWT"
  cloud                           = "AWS"
  secrets_insert                  = "tableflow_kickstarter"
  confluent_secrets_path_prefix   = "/confluent_cloud_resource/${local.secrets_insert}"
  snowflake_secrets_path_prefix   = "/snowflake_resource/${local.secrets_insert}"
  generic_name                    = "${upper(local.secrets_insert)}"
  catalog_integration_name        = "${local.generic_name}_CATALOG_INTEGRATION"
  volume_name                     = "${local.generic_name}_VOLUME"
  user_name                       = "${local.generic_name}_USER"
  warehouse_name                  = "${local.generic_name}_WAREHOUSE"
  database_name                   = "${local.generic_name}_DATABASE"
  schema_name                     = "${local.generic_name}_SCHEMA"
  location_name                   = "${local.generic_name}_LOCATION"
  security_admin_role             = "${local.generic_name}_SECURITY_ADMIN_ROLE"
  system_admin_role               = "${local.generic_name}_SYSTEM_ADMIN_ROLE"
  tableflow_s3_glue_role_name     = "tableflow_s3_glue_role"
  tableflow_s3_glue_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.tableflow_s3_glue_role_name}"
  snowflake_aws_s3_glue_role_name = "snowflake_s3_glue_role"
  snowflake_aws_s3_glue_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.snowflake_aws_s3_glue_role_name}"
  service_account_name            = "${local.secrets_insert}_flink_sql_statements_runner"
  flink_rest_endpoint             = "https://flink.${var.aws_region}.${lower(local.cloud)}.confluent.cloud"
}