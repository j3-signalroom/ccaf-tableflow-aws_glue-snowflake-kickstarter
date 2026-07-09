terraform {
    required_version = ">= 1.13.0"
    
    cloud {
        organization = "signalroom"

        workspaces {
            name = "ccaf-tableflow-aws-glue-snowflake-kickstarter"
        }
    }

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "6.37.0"
        }
        confluent = {
            source  = "confluentinc/confluent"
            version = "2.76.0"
        }
        snowflake = {
            source = "snowflakedb/snowflake"
            version = "2.14.0"
        }
    }
}