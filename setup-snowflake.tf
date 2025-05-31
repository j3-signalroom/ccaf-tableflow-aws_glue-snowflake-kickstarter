resource "snowflake_warehouse" "tableflow" {
  name           = local.warehouse_name
  warehouse_size = "xsmall"
  auto_suspend   = 60
  provider       = snowflake
}

resource "snowflake_database" "tableflow" {
  name     = local.database_name
  provider = snowflake
}

resource "snowflake_schema" "tableflow" {
  name       = local.schema_name
  database   = snowflake_database.tableflow.name
  provider   = snowflake
}

locals {
  topic_name     = confluent_kafka_topic.stock_trades.topic_name
  cluster_id     = confluent_kafka_cluster.kafka_cluster.id
  environment_id = confluent_environment.tableflow_kickstarter.id
  api_key        = module.tableflow_api_key.active_api_key.id
  api_secret     = module.tableflow_api_key.active_api_key.secret
  url            = "https://api.confluent.cloud/tableflow/v1/tableflow-topics/${local.topic_name}?environment=${local.environment_id}&spec.kafka_cluster=${local.cluster_id}"
}

# Perform a GET request to the Tableflow API to retrieve Tableflow info
# from the enabled Tableflow Kafka Topic.
data "http" "tableflow_topic" {
  url    = local.url
  method = "GET"

  request_headers = {
    Authorization = "Basic ${base64encode("${local.api_key}:${local.api_secret}")}"
    Accept        = "application/json"
  }

  retry {
    attempts     = 5
    min_delay_ms = 5000
    max_delay_ms = 9000 
  }

  depends_on = [ 
    confluent_tableflow_topic.stock_trades 
  ]
}

# Ensure that the Tableflow Topic GET RESTful API call made before proceeding
# on to the local variable declaration below.
resource "null_resource" "after_tableflow_topic" {
  triggers = {
    response = data.http.tableflow_topic.response_body
  }
}

# Local that now "depends on" the null-resource via its trigger to get the 
# Tableflow Topic's table_path and base_path from the response body.
locals {
  response_body    = jsondecode(null_resource.after_tableflow_topic.triggers["response"])
  topic_table_path = local.response_body["spec"]["storage"]["table_path"]
  part_before_v1   = split("/v1/", local.topic_table_path)
  base_path        = "${local.part_before_v1[0]}/v1/"
}


resource "snowflake_file_format" "parquet" {
  provider    = snowflake
  name        = "PARQUET_FORMAT"
  database    = snowflake_database.tableflow.name
  schema      = snowflake_schema.tableflow.name 
  format_type = "PARQUET"
  comment     = "File format for Parquet files used in Tableflow Kafka Topic"

  depends_on = [
    snowflake_grant_privileges_to_account_role.schema,
    snowflake_grant_privileges_to_account_role.database,
    snowflake_grant_privileges_to_account_role.warehouse
  ]
}


# Create a Snowflake Stage that points to the S3 bucket where the Tableflow Kafka
# Topic is writing the data. This stage will be used to load data into Snowflake.
resource "snowflake_stage" "stock_trades" {
  provider            = snowflake
  name                = "${upper(confluent_kafka_topic.stock_trades.topic_name)}_STAGE"
  url                 = "${local.topic_table_path}/data/"
  database            = snowflake_database.tableflow.name
  schema              = snowflake_schema.tableflow.name 
  storage_integration = local.aws_s3_integration_name
  comment             = "Stage for stock trades data from Tableflow Kafka Topic"

  depends_on = [
    module.snowflake_glue_s3_access_role,
    snowflake_grant_privileges_to_account_role.integration_grant
  ]
}

locals {
  double_dollar_signs = "_x24_x24"
  dash                = "_x2D"
}

# Create an external table in Snowflake that references the data in the S3 bucket
# that is being populated by the Tableflow Kafka Topic.  This external table will
# allow querying the data directly from Snowflake.
resource "snowflake_external_table" "stock_trades" {
  provider     = snowflake
  database     = snowflake_database.tableflow.name
  schema       = snowflake_schema.tableflow.name
  name         = upper(confluent_kafka_topic.stock_trades.topic_name)
  file_format  = "TYPE = 'PARQUET'" # snowflake_file_format.parquet.name
  pattern      = ".*\\.parquet"
  location     = "@${snowflake_stage.stock_trades.fully_qualified_name}"
  auto_refresh = true
  comment      = "External table for stock trades data from Tableflow Kafka Topic"

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
    snowflake_database.tableflow,
    snowflake_schema.tableflow,
    snowflake_grant_privileges_to_account_role.stage_usage,
    snowflake_grant_privileges_to_account_role.file_format_usage
  ]
}