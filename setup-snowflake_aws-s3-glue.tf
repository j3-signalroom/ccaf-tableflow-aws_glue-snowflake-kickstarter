resource "random_uuid" "s3_bucket" {
}

resource "aws_s3_bucket" "iceberg_bucket" {
  # Ensure the bucket name adheres to the S3 bucket naming conventions and is globally unique.
  bucket        = "${replace(local.secrets_insert, "_", "-")}-${random_uuid.s3_bucket.id}"
  force_destroy = true
}

data "aws_iam_policy_document" "snowflake_s3_access_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = ["arn:aws:s3:::${substr(local.tableflow_topic_s3_base_path,5,length(local.tableflow_topic_s3_base_path))}*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.iceberg_bucket.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["*"]
    }
  }
}

data "aws_iam_policy_document" "snowflake_s3_policy" {  
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [snowflake_external_volume.volume.storage_location[0].storage_aws_role_arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values = [snowflake_external_volume.volume.storage_location[0].storage_aws_external_id]
    }
  }
}

# data "aws_iam_policy_document" "snowflake_glue_access_policy" {
#   statement {
#     sid     = "AllowGlueCatalogTableAccess"
#     effect  = "Allow"
#     actions = [
#       "glue:GetCatalog",
#       "glue:GetDatabase",
#       "glue:GetDatabases",
#       "glue:GetTable",
#       "glue:GetTables"
#     ]
#     resources = [
#       "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:table/*/*",
#       "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:catalog",
#       "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:database/${confluent_kafka_cluster.kafka_cluster.id}"
#     ]
#   }
# }

# data "aws_iam_policy_document" "snowflake_glue_policy" {  
#   statement {
#     effect = "Allow"
#     principals {
#       type        = "AWS"
#       identifiers = [snowflake_storage_integration.aws_s3_integration.storage_aws_iam_user_arn]
#     }
#     actions = ["sts:AssumeRole"]
#     condition {
#       test     = "StringEquals"
#       variable = "sts:ExternalId"
#       values   = [snowflake_storage_integration.aws_s3_integration.storage_aws_external_id]
#     }
#   }

#   depends_on = [ 
#     snowflake_storage_integration.aws_s3_integration
#   ]
# }

# resource "snowflake_storage_integration" "aws_s3_integration" {
#   provider                  = snowflake
#   name                      = local.aws_s3_integration_name
#   storage_allowed_locations = ["${local.tableflow_topic_s3_base_path}"]
#   storage_provider          = "S3"
#   storage_aws_object_acl    = "bucket-owner-full-control"
#   storage_aws_role_arn      = local.snowflake_aws_role_arn
#   enabled                   = true
#   type                      = "EXTERNAL_STAGE"
# }

# # Emits GRANT USAGE ON INTEGRATION <integration_name> TO ROLE <security_admin_role>;
# resource "snowflake_grant_privileges_to_account_role" "integration_usage" {
#   provider          = snowflake.security_admin
#   privileges        = ["USAGE"]
#   account_role_name = local.security_admin_role
#   on_account_object {
#     object_type = "INTEGRATION"
#     object_name = local.aws_s3_integration_name
#   }

#   depends_on = [
#     snowflake_storage_integration.aws_s3_integration
#   ]
# }