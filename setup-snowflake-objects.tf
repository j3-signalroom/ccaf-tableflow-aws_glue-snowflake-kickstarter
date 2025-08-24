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

resource "snowflake_external_volume" "volume" {
  provider = snowflake.account_admin
  name     = local.volume_name
  storage_location {
    storage_location_name = "${local.volume_name}_LOCATION"
    storage_base_url      = local.tableflow_topic_s3_base_path
    storage_provider      = "S3"
    storage_aws_role_arn  = local.snowflake_aws_s3_role_arn
  }

  depends_on = [ 
    confluent_tableflow_topic.stock_trades,
    confluent_tableflow_topic.stock_trades_with_totals
  ]
}

# 2025-08-24:  Snowflake Terraform Provider 2.5.0 does not support the creation of catalog integrations
# resource "snowflake_execute" "catalog_integration" {
#   depends_on = [ 
#     snowflake_external_volume.volume 
#   ]

#   execute = <<EOT
#     CREATE CATALOG INTEGRATION glue_rest_catalog_integration
#       CATALOG_SOURCE = ICEBERG_REST
#       TABLE_FORMAT = ICEBERG
#       CATALOG_NAMESPACE = 'rest_catalog_integration'
#       REST_CONFIG = (
#         CATALOG_URI = 'https://glue.${data.aws_region.current.id}.amazonaws.com/iceberg'
#         CATALOG_API_TYPE = AWS_GLUE
#         CATALOG_NAME = '${data.aws_caller_identity.current.account_id}'
#       )
#       REST_AUTHENTICATION = (
#         TYPE = SIGV4
#         SIGV4_IAM_ROLE = '${local.snowflake_external_volume_aws_role_arn}'
#         SIGV4_EXTERNAL_ID = '${local.snowflake_external_volume_external_id}'
#         SIGV4_SIGNING_REGION = '${data.aws_region.current.id}'
#       )
#       ENABLED = FALSE;
#   EOT

#   revert = <<EOT
#     DROP CATALOG INTEGRATION glue_rest_catalog_integration
#   EOT
# }

# resource "aws_iam_policy" "snowflake_glue_access_policy" {
#   name   = "${local.snowflake_aws_glue_role_name}_access_policy"
#   policy = jsonencode(({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "glue:GetCatalog",
#           "glue:GetDatabase",
#           "glue:GetDatabases",
#           "glue:GetTable",
#           "glue:GetTables"
#         ],
#         Resource = [
#           "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:table/*/*",
#           "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:catalog",
#           "arn:aws:glue:*:${data.aws_caller_identity.current.account_id}:database/${confluent_kafka_cluster.kafka_cluster.id}"
#         ]
#       }
#     ]
#   }))
# }

# # resource "aws_iam_role" "snowflake_glue_role" {
# #   name               = local.snowflake_aws_glue_role_name
# #   description        = "IAM role for Snowflake Glue access"
# #   assume_role_policy = jsonencode({
# #     Version = "2012-10-17",
# #     Statement = [{
# #       Effect = "Allow"
# #       Principal = {
# #         AWS = local.snowflake_external_volume_aws_role_arn
# #       }
# #       Action = "sts:AssumeRole",
# #       Condition = {
# #         StringEquals = {
# #           "sts:ExternalId" = local.snowflake_external_volume_external_id
# #         }
# #       }
# #     }]
# #   })
# # }

# # data "aws_iam_policy_document" "snowflake_glue_policy" {  
# #   statement {
# #     effect = "Allow"
# #     principals {
# #       type        = "AWS"
# #       identifiers = [snowflake_storage_integration.aws_s3_integration.storage_aws_iam_user_arn]
# #     }
# #     actions = ["sts:AssumeRole"]
# #     condition {
# #       test     = "StringEquals"
# #       variable = "sts:ExternalId"
# #       values   = [snowflake_storage_integration.aws_s3_integration.storage_aws_external_id]
# #     }
# #   }

# #   depends_on = [ 
# #     snowflake_storage_integration.aws_s3_integration
# #   ]
# # }


# # resource "aws_iam_role_policy_attachment" "snowflake_glue_policy_attachment" {
# #   role       = aws_iam_role.snowflake_glue_role.name
# #   policy_arn = aws_iam_policy.snowflake_glue_access_policy.arn
# # }

# # resource "snowflake_execute" "create_iceberg_table" {
# #   depends_on = [ 
# #     snowflake_execute.catalog_integration 
# #   ]

# #   execute = <<EOT
# #     CREATE OR REPLACE ICEBERG TABLE stock_trades
# #       EXTERNAL_VOLUME = local.volume_name
# #       CATALOG = 'glue_rest_catalog_integration'
# #       CATALOG_TABLE_NAME = confluent_kafka_topic.stock_trades.topic_name
# #     EOT
# #   revert = <<EOT
# #     DROP ICEBERG TABLE stock_trades
# #   EOT
# # }
