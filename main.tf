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
            version = "2.30.0"
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

resource "confluent_environment" "tableflow_kickstarter" {
  display_name = "${local.secrets_insert}"

  stream_governance {
    package = "ESSENTIALS"
  }
}