
locals {
  cloud                         = "AWS"
  secrets_insert                = "tableflow_kickstarter"
  confluent_secrets_path_prefix = "/confluent_cloud_resource/${local.secrets_insert}"
  snowflake_secrets_path_prefix = "/snowflake_resource/${local.secrets_insert}"
  snowflake_aws_role_name       = "snowflake_role"
  snowflake_aws_role_arn        = "arn:aws:iam::${var.aws_account_id}:role/${local.snowflake_aws_role_name}"
}

# Reference the Confluent Cloud
data "confluent_organization" "env" {}