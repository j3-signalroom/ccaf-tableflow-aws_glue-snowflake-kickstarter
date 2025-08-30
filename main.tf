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
            version = "2.37.0"
        }
        aws = {
            source  = "hashicorp/aws"
            version = "6.10.0"
        }
        snowflake = {
            source = "snowflakedb/snowflake"
            version = "2.5.0"
        }
    }
}
