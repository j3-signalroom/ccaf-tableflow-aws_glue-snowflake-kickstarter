terraform {
    cloud {
      organization = "signalroom"

        workspaces {
            name = "ccaf-tableflow-aws-glue-snowflake-kickstarter"
        }
  }

  required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "6.13.0"
        }
        confluent = {
            source  = "confluentinc/confluent"
            version = "2.40.0"
        }
        snowflake = {
            source = "snowflakedb/snowflake"
            version = "2.7.0"
        }
    }
}
