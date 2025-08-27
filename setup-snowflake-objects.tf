resource "snowflake_warehouse" "tableflow_kickstarter" {
  name           = local.warehouse_name
  warehouse_size = "xsmall"
  auto_suspend   = 60
  provider       = snowflake
}

resource "snowflake_database" "tableflow_kickstarter" {
  name     = local.database_name
  provider = snowflake
  comment  = "Database for Tableflow Kafka Topic data"

  depends_on = [ 
    snowflake_warehouse.tableflow_kickstarter 
  ]
}

resource "snowflake_schema" "tableflow_kickstarter" {
  name       = local.schema_name
  database   = local.database_name
  provider   = snowflake
  comment    = "Schema for Tableflow Kafka Topic data"

  depends_on = [
    snowflake_database.tableflow_kickstarter
  ]
}

resource "snowflake_external_volume" "tableflow_kickstarter_volume" {
  provider     = snowflake.account_admin
  name         = local.volume_name
  allow_writes = false
  storage_location {
    storage_location_name = "${local.volume_name}_LOCATION"
    storage_base_url      = local.tableflow_topic_s3_base_path
    storage_provider      = "S3"
    storage_aws_role_arn  = local.snowflake_aws_s3_glue_role_arn
  }

  depends_on = [ 
    confluent_tableflow_topic.stock_trades,
    confluent_tableflow_topic.stock_trades_with_totals
  ]
}

# Snowflake Terraform Provider 2.5.0 does not support the creation of catalog integrations
resource "snowflake_execute" "catalog_integration" {
  provider = snowflake.account_admin
  depends_on = [ 
    confluent_kafka_cluster.kafka_cluster,
    snowflake_external_volume.tableflow_kickstarter_volume 
  ]

  execute = <<EOT
    CREATE CATALOG INTEGRATION tableflow_kickstarter_catalog_integration
      CATALOG_SOURCE = GLUE
      CATALOG_NAMESPACE = '${confluent_kafka_cluster.kafka_cluster.id}'
      TABLE_FORMAT = ICEBERG
      GLUE_AWS_ROLE_ARN = '${local.snowflake_aws_s3_glue_role_arn}'
      GLUE_CATALOG_ID = '${data.aws_caller_identity.current.account_id}'
      GLUE_REGION = '${var.aws_region}'
      ENABLED = TRUE;
  EOT

  revert = <<EOT
    DROP CATALOG INTEGRATION tableflow_kickstarter_catalog_integration;
  EOT
}

resource "snowflake_execute" "describe_catalog_integration" {
  provider = snowflake.account_admin
  
  depends_on = [ 
    snowflake_execute.catalog_integration 
  ]

  execute = <<EOT
    DESCRIBE CATALOG INTEGRATION tableflow_kickstarter_catalog_integration;
  EOT

  revert = <<EOT
    DESCRIBE CATALOG INTEGRATION tableflow_kickstarter_catalog_integration;
  EOT

  query = <<EOT
    DESCRIBE CATALOG INTEGRATION tableflow_kickstarter_catalog_integration;
  EOT
}

locals {
  result_map = {
    for result in snowflake_execute.describe_catalog_integration.query_results : result["property"] => result
  }
}

resource "aws_iam_role" "snowflake_s3_glue_role" {
  name               = local.snowflake_aws_s3_glue_role_name
  description        = "IAM role for Snowflake S3 and Glue access"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = snowflake_execute.describe_catalog_integration.query_results[8]["property_value"] #local.result_map["GLUE_AWS_ROLE_ARN"]["property_value"]
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = snowflake_execute.describe_catalog_integration.query_results[9]["property_value"] #local.result_map["GLUE_AWS_EXTERNAL_ID"]["property_value"]
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = snowflake_execute.describe_catalog_integration.query_results[8]["property_value"] #local.result_map["GLUE_AWS_ROLE_ARN"]["property_value"]
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
    snowflake_execute.describe_catalog_integration 
  ]
}

resource "aws_iam_policy" "snowflake_s3_glue_role_access_policy" {
  name   = "${local.snowflake_aws_s3_glue_role_name}_access_policy"

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
      },
      {
        Effect = "Allow",
        Action = [
          "glue:GetCatalog",
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables"
        ],
        Resource = [
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/*/*",
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:${var.aws_region}:${data.aws_caller_identity.current.account_id}:database/*"
        ]
      }
    ]
  }))

  depends_on = [
    aws_iam_role.snowflake_s3_glue_role
  ]
}

resource "aws_iam_role_policy_attachment" "snowflake_s3_glue_policy_attachment" {
  role       = aws_iam_role.snowflake_s3_glue_role.name
  policy_arn = aws_iam_policy.snowflake_s3_glue_role_access_policy.arn
}

resource "snowflake_execute" "snowflake_stock_trades_iceberg_table" {
  provider = snowflake.account_admin
  depends_on = [ 
    aws_iam_role_policy_attachment.snowflake_s3_glue_policy_attachment
  ]

  execute = <<EOT
    CREATE OR REPLACE ICEBERG TABLE tableflow_kickstarter.tableflow_kickstarter.stock_trades
      EXTERNAL_VOLUME = '${local.volume_name}'
      CATALOG = 'tableflow_kickstarter_catalog_integration'
      CATALOG_TABLE_NAME = '${confluent_kafka_topic.stock_trades.topic_name}'
    EOT
  revert = <<EOT
    DROP ICEBERG TABLE tableflow_kickstarter.tableflow_kickstarter.stock_trades
  EOT
}