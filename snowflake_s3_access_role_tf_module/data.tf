data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "snowflake_s3_initial_policy" {  
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.id] # This is the AWS account ID of the current caller
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = ["xxxxxxxx"]   # set dummy value
    }
  }
  
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
    resources = ["${var.s3_bucket_arn}/*"]
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