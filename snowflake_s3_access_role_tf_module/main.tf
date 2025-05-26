terraform {
  required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "5.98.0"
        }
        snowflake = {
            source = "snowflakedb/snowflake"
            version = "2.1.0"
        }
    }
}

provider "snowflake" {
  role              = "ACCOUNTADMIN"
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.admin_user
  authenticator     = var.authenticator
  private_key       = var.active_private_key

  # Enable preview features
  preview_features_enabled = [
    "snowflake_storage_integration_resource"
  ]
}
resource "aws_iam_role" "snowflake_s3_role" {
  name               = var.snowflake_s3_role_name
  description        = "IAM role for Snowflake S3 access"
  assume_role_policy = data.aws_iam_policy_document.snowflake_s3_policy.json
}

resource "aws_iam_policy" "snowflake_s3_access_policy" {
  name   = "snowflake_s3_access_policy"
  policy = data.aws_iam_policy_document.snowflake_s3_access_policy.json
}

resource "aws_iam_role_policy_attachment" "snowflake_s3_policy_attachment" {
  role       = aws_iam_role.snowflake_s3_role.name
  policy_arn = aws_iam_policy.snowflake_s3_access_policy.arn
}

resource "snowflake_storage_integration" "aws_s3_integration" {
  provider                  = snowflake
  name                      = var.aws_s3_integration_name
  storage_allowed_locations = ["${var.base_path}"]
  storage_provider          = "S3"
  storage_aws_object_acl    = "bucket-owner-full-control"
  storage_aws_role_arn      = var.snowflake_aws_role_arn
  enabled                   = true
  type                      = "EXTERNAL_STAGE"
}
