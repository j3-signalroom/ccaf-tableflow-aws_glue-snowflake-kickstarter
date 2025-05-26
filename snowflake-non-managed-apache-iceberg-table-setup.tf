provider "snowflake" {
  role  = "SYSADMIN"

  # Snowflake Terraform Provider 1.0.0 requires the `organization_name` and 
  # `account_name` to be set, whereas the previous versions did not require
  # this.  That is why we are setting these values here.  Plus, `account` as
  # been deprecated in favor of `account_name`.
  organization_name = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[0]}"
  account_name      = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[1]}"
  user              = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["admin_user"]
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["active_rsa_public_key_number"] == 1 ? data.aws_secretsmanager_secret_version.admin_private_key_1.secret_string : data.aws_secretsmanager_secret_version.admin_private_key_2.secret_string
}

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

  depends_on = [
    snowflake_database.tableflow
  ]
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
    attempts     = 2
    min_delay_ms = 1000
    max_delay_ms = 2000 
  }
}

# Ensure that the Tableflow Topic GET RESTful API call made before proceeding on to the
# local variable declaration below.
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

resource "snowflake_storage_integration" "aws_s3_integration" {
  provider                  = snowflake.account_admin
  name                      = local.aws_s3_integration_name
  storage_allowed_locations = ["${local.base_path}"]
  storage_provider          = "S3"
  storage_aws_object_acl    = "bucket-owner-full-control"
  storage_aws_role_arn      = local.snowflake_aws_role_arn
  enabled                   = true
  type                      = "EXTERNAL_STAGE"
}

resource "snowflake_stage" "stock_trades" {
  provider            = snowflake.account_admin
  name                = upper("stock_trades_stage")
  url                 = "${local.topic_table_path}/data/"
  database            = snowflake_database.tableflow.name
  schema              = snowflake_schema.tableflow.name
  storage_integration = snowflake_storage_integration.aws_s3_integration.name

  depends_on = [
    module.snowflake_s3_access_role
  ]
}

resource "snowflake_external_table" "stock_trades" {
  provider    = snowflake
  database    = local.database_name
  schema      = local.schema_name
  name        = upper("stock_trades")
  file_format = "TYPE = 'PARQUET'"
  location    = "@${local.database_name}.${local.schema_name}.${snowflake_stage.stock_trades.name}"
  auto_refresh = true

  column {
    as   = "(value:side::string)"
    name = "side"
    type = "VARCHAR"
  }

  column {
    as   = "(value:quantity::bigint)"
    name = "quantity"
    type = "BIGINT"
  }

  column {
    as   = "(value:symbol::string)"
    name = "symbol"
    type = "VARCHAR"
  }

  column {
    as   = "(value:price::bigint)"
    name = "price"
    type = "BIGINT"
  }

  column {
    as   = "(value:account::string)"
    name = "account"
    type = "VARCHAR"
  }

  column {
    as   = "(value:userid::string)"
    name = "userid"
    type = "VARCHAR"
  }

  depends_on = [
    snowflake_stage.stock_trades
  ]
}
