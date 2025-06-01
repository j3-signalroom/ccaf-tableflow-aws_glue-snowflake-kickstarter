data "aws_iam_policy_document" "snowflake_glue_s3_access_policy" {
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
    resources = ["arn:aws:s3:::${substr(var.tableflow_topic_s3_base_path,5,length(var.tableflow_topic_s3_base_path))}*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket"
    ]
    resources = [var.s3_bucket_arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["*"]
    }
  }
}

data "aws_iam_policy_document" "snowflake_glue_s3_policy" {  
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [snowflake_storage_integration.aws_s3_integration.storage_aws_iam_user_arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [snowflake_storage_integration.aws_s3_integration.storage_aws_external_id]
    }
  }
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}