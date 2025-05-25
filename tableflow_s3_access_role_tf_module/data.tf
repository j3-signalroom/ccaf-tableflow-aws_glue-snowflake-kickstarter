data "aws_iam_policy_document" "tableflow_s3_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [var.iam_role_arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }

  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [var.iam_role_arn]
    }
    actions = ["sts:TagSession"]
  }
}

data "aws_iam_policy_document" "tableflow_s3_access_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket"
    ]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:GetObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts"
    ]
    resources = ["arn:aws:s3:::${var.s3_bucket_name}/*"]
  }
}