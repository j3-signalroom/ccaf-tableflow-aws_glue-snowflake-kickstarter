resource "confluent_provider_integration" "tableflow" {
  environment {
    id = confluent_environment.tableflow_kickstarter.id
  }
  aws {
    customer_role_arn = local.snowflake_aws_role_arn
  }
  display_name = "tableflow_aws_integration"
}

resource "confluent_role_binding" "app_manager_provider_integration_resource_owner" {
  principal   = "User:${confluent_service_account.app_manager.id}"
  role_name   = "ResourceOwner"
  crn_pattern = "${confluent_environment.tableflow_kickstarter.resource_name}/provider-integration=${confluent_provider_integration.tableflow.id}"
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
      id = confluent_environment.tableflow_kickstarter.id
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
    id = confluent_environment.tableflow_kickstarter.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }
  display_name = "tableflow_aws_glue_catalog_sync"
  aws_glue {
    provider_integration_id = confluent_provider_integration.tableflow.id
  }
  credentials {
    key    = module.tableflow_api_key.active_api_key.id
    secret = module.tableflow_api_key.active_api_key.secret
  }

  depends_on = [ 
    confluent_role_binding.app_manager_provider_integration_resource_owner,
    module.tableflow_s3_access_role
  ]
}

module "tableflow_s3_access_role" {
  source         = "./tableflow_s3_access_role_tf_module"
  s3_bucket_name = aws_s3_bucket.iceberg_bucket.bucket
  iam_role_arn   = confluent_provider_integration.tableflow.aws[0].iam_role_arn
  external_id    = confluent_provider_integration.tableflow.aws[0].external_id
  iam_role_name  = local.snowflake_aws_role_name
}

resource "confluent_tableflow_topic" "stock_trades" {
  environment {
    id = confluent_environment.tableflow_kickstarter.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }
  display_name = confluent_kafka_topic.stock_trades.topic_name

  byob_aws {
    bucket_name             = aws_s3_bucket.iceberg_bucket.bucket
    provider_integration_id = confluent_provider_integration.tableflow.id
  }

  credentials {
    key    = module.tableflow_api_key.active_api_key.id
    secret = module.tableflow_api_key.active_api_key.secret
  }

  depends_on = [
    module.tableflow_s3_access_role,
    confluent_connector.source
  ]
}