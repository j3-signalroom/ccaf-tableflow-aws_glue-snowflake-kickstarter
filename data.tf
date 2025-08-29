data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_secretsmanager_secret" "admin_user" {
  name = var.admin_user_secrets_root_path
}

data "aws_secretsmanager_secret_version" "admin_user" {
  secret_id = data.aws_secretsmanager_secret.admin_user.id
}

locals {
  cloud                           = "AWS"
  secrets_insert                  = "tableflow_kickstarter"

  # Snowflake connection details from Secrets Manager
  snowflake_account_identifier    = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_account_identifier"]
  snowflake_organization_name     = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_organization_name"]
  snowflake_account_name          = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_account_name"]
  snowflake_admin_user            = jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["new_admin_user"]
  snowflake_active_private_key    = base64decode(jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["active_key_number"] == 1 ? jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_rsa_private_key_1_pem"] : jsondecode(data.aws_secretsmanager_secret_version.admin_user.secret_string)["snowflake_rsa_private_key_2_pem"])

  snowflake_authenticator         = "SNOWFLAKE_JWT"
  
  # Secrets Manager Paths
  confluent_secrets_path_prefix   = "/confluent_cloud_resource/${local.secrets_insert}"
  snowflake_secrets_path_prefix   = "/snowflake_resource/${local.secrets_insert}"
  
  service_account_name            = "${local.secrets_insert}_flink_sql_statements_runner"
  flink_rest_endpoint             = "https://flink.${var.aws_region}.${lower(local.cloud)}.confluent.cloud"

  # Snowflake Object Names
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

  # IAM Role names and ARNs
  tableflow_s3_glue_role_name     = "tableflow_s3_glue_role"
  tableflow_s3_glue_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.tableflow_s3_glue_role_name}"
  snowflake_aws_s3_glue_role_name = "snowflake_s3_glue_role"
  snowflake_aws_s3_glue_role_arn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.snowflake_aws_s3_glue_role_name}"

  # Snowflake DESCRIBE EXTERNAL VOLUME results
  external_volume_properties = {
    for describe_record in snowflake_external_volume.tableflow_kickstarter_volume.describe_output : describe_record.name => describe_record.value
  }

  # Snowflake DESCRIBE CATALOG INTEGRATION results
  catalog_integration_query_result_map = {
    for query_result in snowflake_execute.describe_catalog_integration.query_results : query_result.property => query_result.property_value
  }

  # Tableflow Topics S3 Base Path
  part_before_v1                = split("/v1/", confluent_tableflow_topic.stock_trades.table_path)
  tableflow_topics_s3_base_path = "${local.part_before_v1[0]}/v1/"
}