terraform {
    cloud {
      organization = "signalroom"

        workspaces {
            name = "ccaf-tableflow-aws-glue-snowflake-kickstarter"
        }
  }

  required_providers {
        confluent = {
            source  = "confluentinc/confluent"
            version = "2.29.0"
        }
        aws = {
            source  = "hashicorp/aws"
            version = "5.98.0"
        }
        snowflake = {
            source = "snowflakedb/snowflake"
            version = "2.1.0"
        }
        http = {
          source  = "hashicorp/http"
          version = "3.5.0"
        }
    }
}

module "snowflake_user_rsa_key_pairs_rotation" {   
    source  = "github.com/j3-signalroom/iac-snowflake-user-rsa_key_pairs_rotation-tf_module"

    # Required Input(s)
    aws_region           = var.aws_region
    aws_account_id       = var.aws_account_id
    snowflake_account    = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"]
    service_account_user = local.secrets_insert

    # Optional Input(s)
    secret_insert             = local.secrets_insert
    day_count                 = var.day_count
    aws_lambda_memory_size    = var.aws_lambda_memory_size
    aws_lambda_timeout        = var.aws_lambda_timeout
    aws_log_retention_in_days = var.aws_log_retention_in_days
}


# Create the Confluent Cloud Environment
resource "confluent_environment" "tableflow_kickstarter" {
  display_name = "${local.secrets_insert}"

  stream_governance {
    package = "ESSENTIALS"
  }
}