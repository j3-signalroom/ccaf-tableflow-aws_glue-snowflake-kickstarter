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
    storage_location_name = local.location_name
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
    CREATE CATALOG INTEGRATION ${local.catalog_integration_name}
      CATALOG_SOURCE = GLUE
      TABLE_FORMAT = ICEBERG
      GLUE_AWS_ROLE_ARN = '${local.snowflake_aws_s3_glue_role_arn}'
      GLUE_CATALOG_ID = '${data.aws_caller_identity.current.account_id}'
      GLUE_REGION = '${var.aws_region}'
      CATALOG_NAMESPACE = '${confluent_kafka_cluster.kafka_cluster.id}'
      ENABLED = TRUE;
  EOT

  revert = <<EOT
    DROP CATALOG INTEGRATION "${local.catalog_integration_name}";
  EOT
}

resource "snowflake_execute" "describe_catalog_integration" {
  provider = snowflake.account_admin
  
  depends_on = [ 
    snowflake_execute.catalog_integration 
  ]

  execute = <<EOT
    DESCRIBE CATALOG INTEGRATION ${local.catalog_integration_name};
  EOT

  revert = <<EOT
    DESCRIBE CATALOG INTEGRATION ${local.catalog_integration_name};
  EOT

  query = <<EOT
    DESCRIBE CATALOG INTEGRATION ${local.catalog_integration_name};
  EOT
}

locals {
  result_map = {
    for result in snowflake_execute.describe_catalog_integration.query_results : result["property"] => result
  }
}

resource "snowflake_execute" "use_warehouse" {
  execute = <<EOT
    USE WAREHOUSE ${local.warehouse_name};
  EOT

  revert = <<EOT
    USE WAREHOUSE ${local.warehouse_name};
  EOT

  query = <<EOT
    USE WAREHOUSE ${local.warehouse_name};
  EOT
}

resource "snowflake_execute" "snowflake_stock_trades_iceberg_table" {
  provider = snowflake.account_admin
  depends_on = [ 
    snowflake_external_volume.tableflow_kickstarter_volume,
    snowflake_execute.catalog_integration,
    snowflake_execute.describe_catalog_integration,
    aws_iam_role_policy_attachment.snowflake_s3_glue_policy_attachment,
    snowflake_execute.use_warehouse
  ]

  execute = <<EOT
    CREATE OR REPLACE ICEBERG TABLE ${local.database_name}.${local.schema_name}.${confluent_kafka_topic.stock_trades.topic_name}
      EXTERNAL_VOLUME = '${local.volume_name}'
      CATALOG = '${local.catalog_integration_name}'
      CATALOG_TABLE_NAME = '${confluent_kafka_topic.stock_trades.topic_name}';
    EOT
  revert = <<EOT
    DROP ICEBERG TABLE ${local.database_name}.${local.schema_name}.${confluent_kafka_topic.stock_trades.topic_name}
  EOT
}