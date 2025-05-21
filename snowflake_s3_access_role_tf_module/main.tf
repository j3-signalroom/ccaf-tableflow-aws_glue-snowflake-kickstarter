# Snowflake Role and Policy
resource "aws_iam_role" "snowflake_role" {
  name = "tableflow_snowflake_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "sts:AssumeRole",
        "Principal": {
          "AWS": var.storage_integration_role_arn
        }
        "Condition" : {
          "StringEquals" : {
            "sts:ExternalId" : var.storage_integration_external_id
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "snowflake_s3_access_policy" {
  name = "tableflow_snowflake_s3_access_policy"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ],
        "Resource": [          
          "${var.s3_bucket_arn}/warehouse/*"
        ]
      },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketLocation",
                "s3:ListBucketMultipartUploads",
                "s3:ListBucket"
            ],
            "Resource": var.s3_bucket_arn,
            "Condition": {
                "StringLike": {
                    "s3:prefix": [
                      "*"
                    ]
                }
            }
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "snowflake_policy_attachment" {
  role       = aws_iam_role.snowflake_role.name
  policy_arn = aws_iam_policy.snowflake_s3_access_policy.arn
}