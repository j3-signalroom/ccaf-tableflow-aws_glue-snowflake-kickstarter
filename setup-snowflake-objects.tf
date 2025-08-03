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

resource "aws_iam_role" "snowflake_s3_role" {
  name               = "${local.snowflake_aws_role_name}_s3"
  description        = "IAM role for Snowflake S3 access"
  assume_role_policy = data.aws_iam_policy_document.snowflake_s3_policy.json
}

resource "aws_iam_policy" "snowflake_s3_access_policy" {
  name   = "${local.snowflake_aws_role_name}_s3_access_policy"
  policy = data.aws_iam_policy_document.snowflake_s3_access_policy.json
}

resource "aws_iam_role_policy_attachment" "snowflake_s3_policy_attachment" {
  role       = aws_iam_role.snowflake_s3_role.name
  policy_arn = aws_iam_policy.snowflake_s3_access_policy.arn
}

resource "aws_iam_role" "snowflake_glue_role" {
  name               = "${local.snowflake_aws_role_name}_glue"
  description        = "IAM role for Snowflake Glue access"
  assume_role_policy = data.aws_iam_policy_document.snowflake_glue_policy.json
}

resource "aws_iam_policy" "snowflake_glue_access_policy" {
  name   = "${local.snowflake_aws_role_name}_glue_access_policy"
  policy = data.aws_iam_policy_document.snowflake_glue_access_policy.json
}

resource "aws_iam_role_policy_attachment" "snowflake_glue_policy_attachment" {
  role       = aws_iam_role.snowflake_glue_role.name
  policy_arn = aws_iam_policy.snowflake_glue_access_policy.arn
}

resource "snowflake_external_volume" "volume" {
  name = local.volume_name
  storage_location {
    storage_location_name = "${local.volume_name}_LOCATION"
    storage_base_url     = local.tableflow_topic_s3_base_path
    storage_provider     = "S3"
  }
}

resource "snowflake_file_format" "parquet" {
  provider    = snowflake
  name        = "PARQUET_FORMAT"
  database    = local.database_name
  schema      = local.schema_name
  format_type = "PARQUET"
  comment     = "File format for Parquet files used in Tableflow Kafka Topic"

  depends_on = [
    snowflake_schema.tableflow_kickstarter
  ]
}


# Create a Snowflake Stage that points to the S3 bucket where the Tableflow Kafka
# Topic is writing the data to.  This stage will be used to load data into Snowflake.
resource "snowflake_stage" "stock_trades" {
  provider            = snowflake
  name                = local.stage_name
  url                 = "${local.tableflow_topic_s3_table_path}/data/"
  database            = local.database_name
  schema              = local.schema_name
  storage_integration = local.aws_s3_integration_name
  file_format         = "FORMAT_NAME = ${snowflake_file_format.parquet.fully_qualified_name}"
  comment             = "Stage for stock trades data from Tableflow Kafka Topic"

  depends_on = [
    confluent_tableflow_topic.stock_trades,
    snowflake_schema.tableflow_kickstarter,
    snowflake_file_format.parquet
  ]
}

locals {
  double_dollar_signs = "_x24_x24"
  dash                = "_x2D"
}


# Create an external table in Snowflake that references the data in the S3 bucket
# that is being populated by the Tableflow Kafka Topic.  This external table will
# allow querying the data directly from Snowflake.
resource "snowflake_external_table" "stock_trades_with_metadata" {
  provider     = snowflake
  database     = local.database_name
  schema       = local.schema_name
  name         = "${upper(confluent_kafka_topic.stock_trades.topic_name)}_WITH_METADATA"
  file_format  = "FORMAT_NAME = ${snowflake_file_format.parquet.fully_qualified_name}"
  pattern      = ".*\\.parquet"
  location     = "@${snowflake_stage.stock_trades.fully_qualified_name}"
  auto_refresh = true
  comment      = "External table for stock trades data from Tableflow Kafka Topic.  Along with metadata, key and value columns are included."

  column {
    as   = "(value:key::binary)"
    name = "key"
    type = "binary"
  }

  column {
    as   = "(value:side::varchar)"
    name = "side"
    type = "varchar"
  }

  column {
    as   = "(value:quantity::int)"
    name = "quantity"
    type = "int"
  }

  column {
    as   = "(value:symbol::varchar)"
    name = "symbol"
    type = "varchar"
  }

  column {
    as   = "(value:price::int)"
    name = "price"
    type = "int"
  }

  column {
    as   = "(value:account::varchar)"
    name = "account"
    type = "varchar"
  }

  column {
    as   = "(value:userid::varchar)"
    name = "userid"
    type = "varchar"
  }

  column {
    as   = "(value:${local.double_dollar_signs}topic::varchar)"
    name = "${local.double_dollar_signs}topic"
    type = "varchar"
  }

  column {
    as   = "(value:${local.double_dollar_signs}partition::int)"
    name = "${local.double_dollar_signs}partition"
    type = "int"
  }

  column {
    as   = "(value:${local.double_dollar_signs}headers::variant)"
    name = "${local.double_dollar_signs}headers"
    type = "variant"
  }

  column {
    as   = "(value:${local.double_dollar_signs}leader${local.dash}epoch::int)"
    name = "${local.double_dollar_signs}leader${local.dash}epoch"
    type = "int"
  }

  column {
    as   = "(value:${local.double_dollar_signs}offset::bigint)"
    name = "${local.double_dollar_signs}offset"
    type = "bigint"
  }

  column {
    as   = "to_timestamp_ltz(value:${local.double_dollar_signs}timestamp::varchar)"
    name = "${local.double_dollar_signs}timestamp"
    type = "timestamp_ltz"
  }

  column {
    as   = "(value:${local.double_dollar_signs}timestamp${local.dash}type::varchar)"
    name = "${local.double_dollar_signs}timestamp${local.dash}type"
    type = "varchar"
  }

  column {
    as   = "(value:${local.double_dollar_signs}raw${local.dash}key::binary)"
    name = "${local.double_dollar_signs}raw${local.dash}key"
    type = "binary"
  }

  column {
    as   = "(value:${local.double_dollar_signs}raw${local.dash}value::binary)"
    name = "${local.double_dollar_signs}raw${local.dash}value"
    type = "binary"
  }
  
  depends_on = [
    snowflake_stage.stock_trades
  ]
}

# Create an external table in Snowflake that references the data in the S3 bucket
# that is being populated by the Tableflow Kafka Topic.  This external table will
# allow querying the data directly from Snowflake.
resource "snowflake_external_table" "stock_trades_without_metadata" {
  provider     = snowflake
  database     = local.database_name
  schema       = local.schema_name
  name         = "${upper(confluent_kafka_topic.stock_trades.topic_name)}"
  file_format  = "FORMAT_NAME = ${snowflake_file_format.parquet.fully_qualified_name}"
  pattern      = ".*\\.parquet"
  location     = "@${snowflake_stage.stock_trades.fully_qualified_name}"
  auto_refresh = true
  comment      = "External table for stock trades data from Tableflow Kafka Topic"

  column {
    as   = "(value:quantity::int)"
    name = "quantity"
    type = "int"
  }

  column {
    as   = "(value:symbol::varchar)"
    name = "symbol"
    type = "varchar"
  }

  column {
    as   = "(value:price::int)"
    name = "price"
    type = "int"
  }

  column {
    as   = "(value:account::varchar)"
    name = "account"
    type = "varchar"
  }

  column {
    as   = "(value:userid::varchar)"
    name = "userid"
    type = "varchar"
  }

  depends_on = [
    snowflake_stage.stock_trades
  ]
}