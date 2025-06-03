terraform {
  required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "5.99.1"
        }
        snowflake = {
            source = "snowflakedb/snowflake"
            version = "2.1.0"
        }
    }
}

resource "aws_iam_role" "snowflake_glue_s3_role" {
  name               = var.snowflake_glue_s3_role_name
  description        = "IAM role for Snowflake S3 access"
  assume_role_policy = data.aws_iam_policy_document.snowflake_glue_s3_policy.json
}

resource "aws_iam_policy" "snowflake_glue_s3_access_policy" {
  name   = "snowflake_glue_s3_access_policy"
  policy = data.aws_iam_policy_document.snowflake_glue_s3_access_policy.json
}

resource "aws_iam_role_policy_attachment" "snowflake_glue_s3_policy_attachment" {
  role       = aws_iam_role.snowflake_glue_s3_role.name
  policy_arn = aws_iam_policy.snowflake_glue_s3_access_policy.arn
}

resource "snowflake_storage_integration" "aws_s3_integration" {
  provider                  = snowflake
  name                      = var.aws_s3_integration_name
  storage_allowed_locations = ["${var.tableflow_topic_s3_base_path}"]
  storage_provider          = "S3"
  storage_aws_object_acl    = "bucket-owner-full-control"
  storage_aws_role_arn      = var.snowflake_aws_role_arn
  enabled                   = true
  type                      = "EXTERNAL_STAGE"
}
