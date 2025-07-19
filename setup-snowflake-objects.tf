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

locals {
  base_url = "https://${local.account_identifier}.snowflakecomputing.com"
}

# https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/reference/external-volume
data "http" "create_external_volume" {
  url    = "${local.base_url}/api/v2/external-volumes?createMode=orReplace"
  method = "POST"

  request_headers = {
    "Content-Type"                         = "application/json"
    "Authorization"                        = "Bearer ${local.active_rsa_public_key_jwt}"
    "Accept"                               = "application/json"
    "User-Agent"                           = "Tableflow-AWS-Glue-Kickstarter-External-Volume"
    "X-Snowflake-Authorization-Token-Type" = "KEYPAIR_JWT"
  }

  request_body = jsonencode({
    name      = local.volume_name
    storage_locations = [{
      storage_provider     = "S3"
      encryption           = "NONE"
      name                 = "${local.volume_name}-LOCATION"
      storage_base_url     = local.tableflow_topic_s3_base_path
      storage_aws_role_arn = local.snowflake_aws_role_arn
    }]
    allow_writes = false
  })

  retry {
    attempts     = 5
    min_delay_ms = 5000
    max_delay_ms = 9000 
  }

  depends_on = [ 
    snowflake_grant_account_role.user_system_admin
   ]
}

resource "null_resource" "after_create_external_volume" {
  triggers = {
    response = data.http.create_external_volume.response_body
  }
}

locals {
  volume_response_body    = jsondecode(null_resource.after_create_external_volume.triggers["response"])
  storage_aws_role_arn    = local.volume_response_body["storage_locations"][0]["storage_aws_role_arn"]
  storage_aws_external_id = local.volume_response_body["storage_locations"][0]["storage_aws_external_id"]
}

# https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/reference/catalog-integration#post--api-v2-catalog-integrations
data "http" "create_catalog_integration" {
  url    = "${local.base_url}/api/v2/catalog-integrations?createMode=orReplace"
  method = "POST"

  request_headers = {
    "Content-Type"                         = "application/json"
    "Authorization"                        = "Bearer ${local.active_rsa_public_key_jwt}"
    "Accept"                               = "application/json"
    "User-Agent"                           = "Tableflow-AWS-Glue-Kickstarter-Catalog-Integration"
    "X-Snowflake-Authorization-Token-Type" = "KEYPAIR_JWT"
  }

  request_body = jsonencode({
    name      = local.catalog_integration_name
    catalog = {
      catalog_source = "GLUE"
    }
    table_format = "ICEBERG"
    enabled      = true
  })

  retry {
    attempts     = 5
    min_delay_ms = 5000
    max_delay_ms = 9000 
  }
}

resource "null_resource" "after_create_catalog_integration" {
  triggers = {
    response = data.http.create_catalog_integration.response_body
  }
}

# https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/reference/catalog-integration#get--api-v2-catalog-integrations-name
data "http" "get_catalog_integration" {
  url    = "${local.base_url}/api/v2/catalog-integrations/${local.catalog_integration_name}"
  method = "GET"

  request_headers = {
    "Content-Type"                         = "application/json"
    "Authorization"                        = "Bearer ${local.active_rsa_public_key_jwt}"
    "Accept"                               = "application/json"
    "User-Agent"                           = "Tableflow-AWS-Glue-Kickstarter-Get-Catalog-Integration"
    "X-Snowflake-Authorization-Token-Type" = "KEYPAIR_JWT"
  }

  request_body = jsonencode({
    name      = local.catalog_integration_name
    catalog = {
      catalog_source = "GLUE"
    }
    table_format = "ICEBERG"
    enabled      = true
  })

  retry {
    attempts     = 5
    min_delay_ms = 5000
    max_delay_ms = 9000 
  }
}

resource "null_resource" "after_get_catalog_integration" {
  triggers = {
    response = data.http.get_catalog_integration.response_body
  }
}

locals {
  catalog_response_body = jsondecode(null_resource.after_get_catalog_integration.triggers["response"])
  glue_aws_role_arn     = local.catalog_response_body["catalog"]["glue_aws_role_arn"]
}
