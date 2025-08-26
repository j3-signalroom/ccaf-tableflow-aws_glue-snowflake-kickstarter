resource "aws_iam_role" "tableflow_s3_glue_role" {
  name               = local.tableflow_s3_glue_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = confluent_provider_integration.tableflow.aws[0].iam_role_arn
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = confluent_provider_integration.tableflow.aws[0].external_id
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = confluent_provider_integration.tableflow.aws[0].iam_role_arn
        }
        Action = "sts:TagSession"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  depends_on = [
    confluent_provider_integration.tableflow
  ]
}

resource "aws_iam_policy" "tableflow_s3_glue_access_policy" {
  name   = "tableflow_s3_glue_access_policy"
  policy = jsonencode(({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucket"
        ],
        Resource = "arn:aws:s3:::${aws_s3_bucket.iceberg_bucket.bucket}"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:GetObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ],
        Resource = "arn:aws:s3:::${aws_s3_bucket.iceberg_bucket.bucket}/*"
      },
      {
        Effect = "Allow",
        Action = [
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
        ],
         Resource = "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  }))

  depends_on = [
    confluent_provider_integration.tableflow
  ]
}

resource "aws_iam_role_policy_attachment" "tableflow_s3_glue_policy_attachment" {
  role       = aws_iam_role.tableflow_s3_glue_role.name
  policy_arn = aws_iam_policy.tableflow_s3_glue_access_policy.arn
}