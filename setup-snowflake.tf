# Create the Snowflake user RSA keys pairs
module "snowflake_user_rsa_key_pairs_rotation" {   
  source  = "github.com/j3-signalroom/iac-snowflake-user-rsa_key_pairs_rotation-tf_module"

  # Required Input(s)
  aws_region                = var.aws_region
  aws_account_id            = data.aws_caller_identity.current.account_id
  snowflake_account         = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"]
  service_account_user      = local.secrets_insert

  # Optional Input(s)
  secret_insert             = local.secrets_insert
  day_count                 = var.day_count
  aws_lambda_memory_size    = var.aws_lambda_memory_size
  aws_lambda_timeout        = var.aws_lambda_timeout
  aws_log_retention_in_days = var.aws_log_retention_in_days
}

provider "snowflake" {
  role              = "SYSADMIN"
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.admin_user
  authenticator     = local.authenticator
  private_key       = local.active_private_key

  # Enable preview features
  preview_features_enabled = [
    "snowflake_file_format_resource",
    "snowflake_stage_resource",
    "snowflake_external_table_resource"
  ]
}

provider "snowflake" {
  alias             = "security_admin"
  role              = "SECURITYADMIN"
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.admin_user
  authenticator     = local.authenticator
  private_key       = local.active_private_key
}

resource "snowflake_account_role" "security_admin_role" {
  provider = snowflake.security_admin
  name     = "${upper(local.secrets_insert)}_ROLE"
}

resource "snowflake_user" "user" {
  provider          = snowflake.security_admin
  name              = local.user_name
  default_warehouse = local.warehouse_name
  default_role      = snowflake_account_role.security_admin_role.name
  default_namespace = "${local.database_name}.${local.schema_name}"

  # Setting the attributes to `null`, effectively unsets the attribute
  # Refer to this link `https://docs.snowflake.com/en/user-guide/key-pair-auth#configuring-key-pair-rotation`
  # for more information
  rsa_public_key    = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 1 ? jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_1"] : null
  rsa_public_key_2  = module.snowflake_user_rsa_key_pairs_rotation.active_rsa_public_key_number == 2 ? jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_2"] : null

  depends_on = [ 
    snowflake_account_role.security_admin_role,
    module.snowflake_user_rsa_key_pairs_rotation
  ]
}

provider "snowflake" {
  alias             = "account_admin"
  role              = "ACCOUNTADMIN"
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.admin_user
  authenticator     = local.authenticator
  private_key       = local.active_private_key

  # Enable preview features
  preview_features_enabled = [
    "snowflake_storage_integration_resource",
    "snowflake_stage_resource",
    "snowflake_external_table_resource"
  ]
}

resource "snowflake_account_role" "account_admin_role" {
  provider = snowflake.account_admin
  name     = local.account_admin_role
}

resource "snowflake_grant_privileges_to_account_role" "user" {
  provider          = snowflake.security_admin
  privileges        = ["MONITOR"]
  account_role_name = snowflake_account_role.security_admin_role.name  
  on_account_object {
    object_type = "USER"
    object_name = local.user_name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.security_admin_role 
  ]
}

resource "snowflake_grant_account_role" "user_security_admin" {
  provider  = snowflake.security_admin
  role_name = snowflake_account_role.security_admin_role.name
  user_name = local.user_name

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.security_admin_role 
  ]
}

resource "snowflake_warehouse" "tableflow" {
  name           = local.warehouse_name
  warehouse_size = "xsmall"
  auto_suspend   = 60
  provider       = snowflake
}

resource "snowflake_grant_privileges_to_account_role" "warehouse" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.security_admin_role.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = local.warehouse_name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.security_admin_role,
    snowflake_warehouse.tableflow
  ]
}

resource "snowflake_database" "tableflow" {
  name     = local.database_name
  provider = snowflake
}

resource "snowflake_grant_privileges_to_account_role" "database" {
  provider          = snowflake.account_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.tableflow.name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role,
    snowflake_warehouse.tableflow,
    snowflake_database.tableflow
  ]
}

resource "snowflake_schema" "tableflow" {
  name       = local.schema_name
  database   = snowflake_database.tableflow.name
  provider   = snowflake
}

resource "snowflake_grant_privileges_to_account_role" "schema" {
  provider          = snowflake.account_admin
  privileges        = ["CREATE STAGE", "CREATE FILE FORMAT", "USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_schema {
    schema_name = "${local.database_name}.${local.schema_name}"
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role,
    snowflake_warehouse.tableflow,
    snowflake_database.tableflow,
    snowflake_schema.tableflow
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
    attempts     = 5
    min_delay_ms = 5000
    max_delay_ms = 9000 
  }

  depends_on = [ 
    confluent_tableflow_topic.stock_trades 
  ]
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

module "snowflake_glue_s3_access_role" {
  source                      = "./modules/snowflake_glue_s3_access_role"
  s3_bucket_arn               = aws_s3_bucket.iceberg_bucket.arn
  snowflake_glue_s3_role_name = local.snowflake_aws_role_name
  snowflake_aws_role_arn      = local.snowflake_aws_role_arn
  aws_s3_integration_name     = local.aws_s3_integration_name
  base_path                   = local.base_path
  organization_name           = local.organization_name
  account_name                = local.account_name
  admin_user                  = local.admin_user
  authenticator               = local.authenticator
  active_private_key          = local.active_private_key
}

resource "snowflake_grant_privileges_to_account_role" "integration_grant" {
  provider          = snowflake.account_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_account_object {
    object_type = "INTEGRATION"
    object_name = local.aws_s3_integration_name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role,
    module.snowflake_glue_s3_access_role
  ]
}

resource "snowflake_grant_account_role" "user_account_admin" {
  provider  = snowflake.account_admin
  role_name = snowflake_account_role.account_admin_role.name
  user_name = snowflake_user.user.name
  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role 
  ]
}

# Create a Snowflake Stage that points to the S3 bucket where the Tableflow Kafka Topic
# is writing the data. This stage will be used to load data into Snowflake.
resource "snowflake_stage" "stock_trades" {
  provider            = snowflake.account_admin
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

# Create an external table in Snowflake that references the data in the S3 bucket
# that is being populated by the Tableflow Kafka Topic.
# This external table will allow querying the data directly from Snowflake.
# resource "snowflake_external_table" "stock_trades" {
#   provider    = snowflake.account_admin
#   database    = snowflake_database.tableflow.name
#   schema      = snowflake_schema.tableflow.name
#   name        = upper(confluent_kafka_topic.stock_trades.topic_name)
#   file_format = "TYPE = 'PARQUET'"
#   location    = "@${snowflake_database.tableflow.name}.${snowflake_schema.tableflow.name}.${snowflake_stage.stock_trades.name}"
#   auto_refresh = true
#   comment      = "External table for stock trades data from Tableflow Kafka Topic"

#   column {
#     as   = "(value:key::binary)"
#     name = "key"
#     type = "binary"
#   }

#   column {
#     as   = "(value:side::varchar)"
#     name = "side"
#     type = "varchar"
#   }

#   column {
#     as   = "(value:quantity::int)"
#     name = "quantity"
#     type = "int"
#   }

#   column {
#     as   = "(value:symbol::varchar)"
#     name = "symbol"
#     type = "varchar"
#   }

#   column {
#     as   = "(value:price::int)"
#     name = "price"
#     type = "int"
#   }

#   column {
#     as   = "(value:account::varchar)"
#     name = "account"
#     type = "varchar"
#   }

#   column {
#     as   = "(value:userid::varchar)"
#     name = "userid"
#     type = "varchar"
#   }

#   column {
#     as   = "(value:_x24_x24topic::varchar)"
#     name = "_x24_x24topic"
#     type = "varchar"
#   }

#   column {
#     as   = "(value:_x24_x24partition::int)"
#     name = "_x24_x24partition"
#     type = "int"
#   }

#   column {
#     as   = "(value:_x24_x24headers::variant)"
#     name = "_x24_x24headers"
#     type = "variant"
#   }

#   column {
#     as   = "(value:_x24_x24leader_x2Depoch::int)"
#     name = "_x24_x24leader_x2Depoch"
#     type = "int"
#   }

#   column {
#     as   = "(value:_x24_x24offset::bigint)"
#     name = "_x24_x24offset"
#     type = "bigint"
#   }

#   column {
#     as   = "to_timestamp_ltz(value:_x24_x24timestamp::varchar)"
#     name = "_x24_x24timestamp"
#     type = "timestamp_ltz"
#   }

#   column {
#     as   = "(value:_x24_x24timestamp_x2Dtype::varchar)"
#     name = "_x24_x24timestamp_x2Dtype"
#     type = "varchar"
#   }

#   column {
#     as   = "(value:_x24_x24raw_x2Dkey::binary)"
#     name = "_x24_x24raw_x2Dkey"
#     type = "binary"
#   }

#   column {
#     as   = "(value:_x24_x24raw_x2Dvalue::binary)"
#     name = "_x24_x24raw_x2Dvalue"
#     type = "binary"
#   }
  
#   depends_on = [
#     snowflake_stage.stock_trades
#   ]
# }