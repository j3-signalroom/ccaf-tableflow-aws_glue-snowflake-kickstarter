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
      identifiers = [local.storage_aws_role_arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [local.storage_aws_external_id]
    }
  }
}

data "aws_iam_policy_document" "snowflake_glue_access_policy" {
  statement {
    sid     = "AllowGlueCatalogTableAccess"
    effect  = "Allow"
    actions = [
      "glue:GetCatalog",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables"
    ]
    resources = [
      "arn:aws:glue:*:<accountid>:table/*/*",
      "arn:aws:glue:*:<accountid>:catalog",
      "arn:aws:glue:*:<accountid>:database/${confluent_kafka_cluster.kafka_cluster.id}"
    ]
  }
}

data "aws_iam_policy_document" "snowflake_glue_policy" {  
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.glue_aws_role_arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [local.storage_aws_external_id]
    }
  }
}