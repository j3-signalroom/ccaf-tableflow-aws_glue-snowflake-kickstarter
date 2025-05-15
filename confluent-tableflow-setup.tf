resource "confluent_provider_integration" "env" {
  environment {
    id = confluent_environment.env.id
  }
  aws {
    customer_role_arn = local.snowflake_aws_role_arn
  }
  display_name = "tableflow_aws_integration"
}

module "tableflow_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.app_manager.id
    api_version = confluent_service_account.app_manager.api_version
    kind        = confluent_service_account.app_manager.kind
  }

  resource = {
    id          = "tableflow"
    api_version = "tableflow/v1"
    kind        = "Tableflow"

    environment = {
      id = confluent_environment.env.id
    }
  }

  confluent_api_key    = var.confluent_api_key
  confluent_api_secret = var.confluent_api_secret

  # Optional Input(s)
  key_display_name             = "Confluent Tableflow Service Account API Key - {date} - Managed by Terraform Cloud"
  number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
  day_count                    = var.day_count
}

resource "confluent_catalog_integration" "tableflow" {
  environment {
    id = confluent_environment.env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }
  display_name = "tableflow_aws_glue_catalog_sync"
  aws_glue {
    provider_integration_id = confluent_provider_integration.env.id
  }
  credentials {
    key    = module.tableflow_api_key.active_api_key.id
    secret = module.tableflow_api_key.active_api_key.secret
  }
}
