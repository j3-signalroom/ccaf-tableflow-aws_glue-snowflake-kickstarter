resource "random_uuid" "s3_bucket" {
}

resource "aws_s3_bucket" "iceberg_bucket" {
  # Ensure the bucket name adheres to the S3 bucket naming conventions and is globally unique.
  bucket        = "${replace(local.secrets_insert, "_", "-")}-${random_uuid.s3_bucket.id}"
  force_destroy = true
}

resource "aws_iam_role" "snowflake_s3_role" {
  name               = local.snowflake_aws_s3_role_name
  description        = "IAM role for Snowflake S3 access"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = local.snowflake_external_volume_aws_role_arn
      }
      Action = "sts:AssumeRole",
      Condition = {
        StringEquals = {
          "sts:ExternalId" = local.snowflake_external_volume_external_id
        }
      }
    }]
  })
}

resource "aws_iam_policy" "snowflake_s3_role_access_policy" {
  name   = "${local.snowflake_aws_s3_role_name}_access_policy"
  policy = jsonencode(({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ],
        Resource = "arn:aws:s3:::${local.tableflow_topic_s3_base_path}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucket"
        ],
        Resource = aws_s3_bucket.iceberg_bucket.arn,
        Condition = {
          StringLike = {
            "s3:prefix" = ["*"]
          }
        }
      }
    ]
  }))
}

resource "aws_iam_role_policy_attachment" "snowflake_s3_policy_attachment" {
  role       = aws_iam_role.snowflake_s3_role.name
  policy_arn = aws_iam_policy.snowflake_s3_role_access_policy.arn
}