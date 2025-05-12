terraform {
    cloud {
      organization = "signalroom"

        workspaces {
            name = "ccaf-tableflow-postgres-snowflake-kickstarter"
        }
  }

  # Using the "pessimistic constraint operators" for all the Providers to ensure
  # that the provider version is compatible with the configuration.  Meaning
  # only patch-level updates are allowed but minor-level and major-level 
  # updates of the Providers are not allowed
  required_providers {
        confluent = {
            source  = "confluentinc/confluent"
            version = "~> 2.28.0"
        }
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.97.0"
        }
        snowflake = {
            source = "Snowflake-Labs/snowflake"
            version = "~> 1.0.5"
        }
    }
}

# Create the Confluent Cloud Environment
resource "confluent_environment" "env" {
  display_name = "${local.secrets_insert}"

  stream_governance {
    package = "ESSENTIALS"
  }
}