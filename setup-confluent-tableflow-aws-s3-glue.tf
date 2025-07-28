data "aws_iam_policy_document" "tableflow_glue_s3_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [confluent_provider_integration.tableflow.aws[0].iam_role_arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [confluent_provider_integration.tableflow.aws[0].external_id]
    }
  }
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [confluent_provider_integration.tableflow.aws[0].iam_role_arn]
    }
    actions = ["sts:TagSession"]
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

data "aws_iam_policy_document" "tableflow_glue_s3_access_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucketMultipartUploads",
      "s3:ListBucket"
    ]
    resources = ["arn:aws:s3:::${aws_s3_bucket.iceberg_bucket.bucket}"]
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
    resources = ["arn:aws:s3:::${aws_s3_bucket.iceberg_bucket.bucket}/*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "glue:DeleteTable",
      "glue:DeleteDatabase",
      "glue:CreateTable",
      "glue:CreateDatabase",
      "glue:UpdateTable",
      "glue:UpdateDatabase",
      "glue:GetTable",
      "glue:GetDatabase",
      "glue:GetTables",
      "glue:GetDatabases",
      "glue:GetTableVersion",
      "glue:GetTableVersions"
    ]
     resources = ["arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
  }
}

resource "aws_iam_role" "tableflow_glue_s3_role" {
  name               = local.tableflow_glue_s3_role_name
  assume_role_policy = data.aws_iam_policy_document.tableflow_glue_s3_policy.json

  depends_on = [
    confluent_provider_integration.tableflow
  ]
}

resource "aws_iam_policy" "tableflow_glue_s3_access_policy" {
  name   = "tableflow_glue_s3_access_policy"
  policy = data.aws_iam_policy_document.tableflow_glue_s3_access_policy.json

  depends_on = [
    confluent_provider_integration.tableflow
  ]
}

resource "aws_iam_role_policy_attachment" "tableflow_glue_s3_policy_attachment" {
  role       = aws_iam_role.tableflow_glue_s3_role.name
  policy_arn = aws_iam_policy.tableflow_glue_s3_access_policy.arn
}