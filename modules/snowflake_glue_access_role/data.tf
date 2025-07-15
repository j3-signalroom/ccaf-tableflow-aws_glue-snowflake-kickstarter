data "aws_caller_identity" "current" {}

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
      "arn:aws:glue:*:<accountid>:database/${var.kafka_cluster_id}"
    ]
  }
}

data "aws_iam_policy_document" "snowflake_glue_policy" {  
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [var.snowflake_aws_role_arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [snowflake_external_volume.external_volume.storage_location.storage_aws_external_id]
    }
  }
}
