terraform {
  required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "6.3.0"
        }
    }
}

# data "aws_caller_identity" "current" {}
# ${data.aws_caller_identity.current.account_id}

resource "aws_iam_role" "snowflake_glue_role" {
  name               = var.catalog_integration_name
  description        = "IAM role for Snowflake Glue access"
  assume_role_policy = data.aws_iam_policy_document.snowflake_glue_policy.json
}

resource "aws_iam_policy" "snowflake_glue_access_policy" {
  name   = "snowflake_glue_access_policy"
  policy = data.aws_iam_policy_document.snowflake_glue_access_policy.json
}

resource "aws_iam_role_policy_attachment" "snowflake_glue_policy_attachment" {
  role       = aws_iam_role.snowflake_glue_role.name
  policy_arn = aws_iam_policy.snowflake_glue_access_policy.arn
}

data "http" "catalog_integration" {
  url    = "https://${var.account_name}.snowflakecomputing.com/api/v2/statements"
  method = "POST"

  request_headers = {
    Authorization = "Basic ${base64encode("${module.tableflow_api_key.active_api_key.id}:${module.tableflow_api_key.active_api_key.secret}")}"
    Accept        = "application/json"
  }

  request_body = jsonencode({
    "statement" : {
      
    }
  } )

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
resource "null_resource" "after_catalog_integration" {
  triggers = {
    response = data.http.catalog_integration.response_body
  }
}

# Local that now "depends on" the null-resource via its trigger to get the 
# Tableflow Topic's tableflow_topic_s3_table_path and 
# tableflow_topic_s3_base_path from the response body.
locals {
  response_body                 = jsondecode(null_resource.after_tableflow_topic.triggers["response"])
  tableflow_topic_s3_table_path = local.response_body["spec"]["storage"]["table_path"]
  part_before_v1                = split("/v1/", local.tableflow_topic_s3_table_path)
  tableflow_topic_s3_base_path  = "${local.part_before_v1[0]}/v1/"
}


# Emits GRANT USAGE ON CATALOG INTEGRATION <catalog_integration_name> TO ROLE <security_admin_role>;
resource "snowflake_grant_privileges_to_account_role" "catalog_integration_name" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = var.security_admin_role_name
  on_account_object {
    object_type = "CATALOG INTEGRATION"
    object_name = var.catalog_integration_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.snowflake_glue_policy_attachment
  ]
}
