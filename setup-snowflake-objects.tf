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
    storage_aws_role_arn = local.snowflake_aws_role_arn
  }
}

locals {
  base_url = "https://${local.account_identifier}.snowflakecomputing.com"
}

# https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/reference/catalog-integration#post--api-v2-catalog-integrations
data "http" "create_catalog_integration" {
  url    = "${local.base_url}/api/v2/catalog-integrations?createMode=orReplace"
  method = "POST"

  request_headers = {
    "Content-Type"                         = "application/json"
    "Authorization"                        = "Bearer ${snowflake_user_programmatic_access_token.pat.token}"
    "Accept"                               = "application/json"
    "User-Agent"                           = "Tableflow-AWS-Glue-Kickstarter-Catalog-Integration"
    "X-Snowflake-Authorization-Token-Type" = "PROGRAMMATIC_ACCESS_TOKEN"
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
  depends_on = [
    module.snowflake_user_rsa_key_pairs_rotation
  ]
}


resource "snowflake_grant_privileges_to_account_role" "integration_usage" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.security_admin_role.name
  on_account_object {
    object_type = "INTEGRATION"
    object_name = local.catalog_integration_name
  }

  depends_on = [ 
    snowflake_grant_account_role.user_security_admin
  ]
}

resource "null_resource" "after_create_catalog_integration" {
  triggers = {
    response = data.http.create_catalog_integration.response_body
  }

  depends_on = [ 
    snowflake_grant_privileges_to_account_role.integration_usage
  ]
}

# https://docs.snowflake.com/en/developer-guide/snowflake-rest-api/reference/catalog-integration#get--api-v2-catalog-integrations-name
data "http" "get_catalog_integration" {
  url    = "${local.base_url}/api/v2/catalog-integrations/${local.catalog_integration_name}"
  method = "GET"

  request_headers = {
    "Content-Type"                         = "application/json"
    "Authorization"                        = "Bearer ${snowflake_user_programmatic_access_token.pat.token}"
    "Accept"                               = "application/json"
    "User-Agent"                           = "Tableflow-AWS-Glue-Kickstarter-Get-Catalog-Integration"
    "X-Snowflake-Authorization-Token-Type" = "PROGRAMMATIC_ACCESS_TOKEN"
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

  depends_on = [
    module.snowflake_user_rsa_key_pairs_rotation
  ]
}

resource "null_resource" "after_get_catalog_integration" {
  triggers = {
    response = data.http.get_catalog_integration.response_body
  }
}
