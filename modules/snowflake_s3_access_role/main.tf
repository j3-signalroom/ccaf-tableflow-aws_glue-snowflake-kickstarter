terraform {
  required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "6.3.0"
        }
        snowflake = {
            source = "snowflakedb/snowflake"
            version = "2.3.0"
        }
    }
}

resource "aws_iam_role" "snowflake_s3_role" {
  name               = var.snowflake_glue_s3_role_name
  description        = "IAM role for Snowflake S3 access"
  assume_role_policy = data.aws_iam_policy_document.snowflake_s3_policy.json
}

resource "aws_iam_policy" "snowflake_s3_access_policy" {
  name   = "snowflake_glue_s3_access_policy"
  policy = data.aws_iam_policy_document.snowflake_s3_access_policy.json
}

resource "aws_iam_role_policy_attachment" "snowflake_s3_policy_attachment" {
  role       = aws_iam_role.snowflake_s3_role.name
  policy_arn = aws_iam_policy.snowflake_s3_access_policy.arn
}

resource "snowflake_external_volume" "external_volume" {
  name                     = var.volume_name
  provider                 = snowflake
  storage_location {
    storage_location_name = "${var.volume_name}-LOCATION"
    storage_provider      = "S3"
    storage_base_url      = var.tableflow_topic_s3_base_path
    storage_aws_role_arn  = var.snowflake_aws_role_arn
  }
}

# Emits GRANT USAGE ON EXTERNAL VOUME <volume_name> TO ROLE <security_admin_role>;
resource "snowflake_grant_privileges_to_account_role" "volume_name" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = var.security_admin_role_name
  on_account_object {
    object_type = "EXTERNAL VOLUME"
    object_name = var.volume_name
  }

  depends_on = [
    snowflake_external_volume.external_volume,
    aws_iam_role_policy_attachment.snowflake_s3_policy_attachment
  ]
}
