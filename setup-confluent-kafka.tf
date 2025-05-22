# Create the Kafka cluster
resource "confluent_kafka_cluster" "kafka_cluster" {
  display_name = local.secrets_insert
  availability = "SINGLE_ZONE"
  cloud        = local.cloud
  region       = var.aws_region
  basic {}

  environment {
    id = confluent_environment.env.id
  }
}

# 'app_manager' service account is required in this configuration to create 'stock_trades' topic and grant ACLs
# to 'app_producer' and 'app_consumer' service accounts.
resource "confluent_service_account" "app_manager" {
  display_name = "tableflow_app_manager"
  description  = "Tableflow Kickstarter Service account to manage Kafka cluster"

  depends_on = [ 
    confluent_kafka_cluster.kafka_cluster 
  ]
}

resource "confluent_role_binding" "app_manager_kafka_cluster_admin" {
  principal   = "User:${confluent_service_account.app_manager.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.kafka_cluster.rbac_crn

  depends_on = [ 
    confluent_service_account.app_manager 
  ]
}

# Creates the app_manager Kafka Cluster API Key Pairs, rotate them in accordance to a time schedule,
# and provide the current acitve API Key Pair to use
module "kafka_app_manager_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.app_manager.id
    api_version = confluent_service_account.app_manager.api_version
    kind        = confluent_service_account.app_manager.kind
  }

  resource = {
    id          = confluent_kafka_cluster.kafka_cluster.id
    api_version = confluent_kafka_cluster.kafka_cluster.api_version
    kind        = confluent_kafka_cluster.kafka_cluster.kind

    environment = {
      id = confluent_environment.env.id
    }
  }

  confluent_api_key    = var.confluent_api_key
  confluent_api_secret = var.confluent_api_secret

  # Optional Input(s)
  key_display_name             = "Confluent Kafka Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
  number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
  day_count                    = var.day_count
}

# Create the `stock_trades` Kafka topic
resource "confluent_kafka_topic" "stock_trades" {
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }
  topic_name    = "stock_trades"
  rest_endpoint = confluent_kafka_cluster.kafka_cluster.rest_endpoint
  credentials {
    key    = module.kafka_app_manager_api_key.active_api_key.id
    secret = module.kafka_app_manager_api_key.active_api_key.secret
  }

  depends_on = [ 
    confluent_role_binding.app_manager_kafka_cluster_admin,
    module.kafka_app_manager_api_key 
  ]
}

resource "confluent_service_account" "app_consumer" {
  display_name = "tableflow_app_consumer"
  description  = "Tableflow Kickstarter Service account to consume from 'stock_trades' topic of Kafka cluster"
}

module "kafka_app_consumer_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.app_consumer.id
    api_version = confluent_service_account.app_consumer.api_version
    kind        = confluent_service_account.app_consumer.kind
  }

  resource = {
    id          = confluent_kafka_cluster.kafka_cluster.id
    api_version = confluent_kafka_cluster.kafka_cluster.api_version
    kind        = confluent_kafka_cluster.kafka_cluster.kind

    environment = {
      id = confluent_environment.env.id
    }
  }

  confluent_api_key    = var.confluent_api_key
  confluent_api_secret = var.confluent_api_secret

  # Optional Input(s)
  key_display_name             = "Confluent Kafka Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
  number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
  day_count                    = var.day_count
}

resource "confluent_kafka_acl" "app_producer_write_on_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.stock_trades.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_producer.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.kafka_cluster.rest_endpoint
  credentials {
    key    = module.kafka_app_manager_api_key.active_api_key.id
    secret = module.kafka_app_manager_api_key.active_api_key.secret
  }
}

resource "confluent_service_account" "app_producer" {
  display_name = "tableflow_app_producer"
  description  = "Tableflow Kickstarter Service account to produce to 'stock_trades' topic of Kafka cluster"
}

module "kafka_app_producer_api_key" {
  source = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

  #Required Input(s)
  owner = {
    id          = confluent_service_account.app_producer.id
    api_version = confluent_service_account.app_producer.api_version
    kind        = confluent_service_account.app_producer.kind
  }

  resource = {
    id          = confluent_kafka_cluster.kafka_cluster.id
    api_version = confluent_kafka_cluster.kafka_cluster.api_version
    kind        = confluent_kafka_cluster.kafka_cluster.kind

    environment = {
      id = confluent_environment.env.id
    }
  }

  confluent_api_key    = var.confluent_api_key
  confluent_api_secret = var.confluent_api_secret

  # Optional Input(s)
  key_display_name             = "Confluent Kafka Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
  number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
  day_count                    = var.day_count
}


resource "confluent_kafka_acl" "app_consumer_read_on_group" {
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }
  resource_type = "GROUP"
  resource_name = "tableflow_kickstarter"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.kafka_cluster.rest_endpoint
  credentials {
    key    = module.kafka_app_manager_api_key.active_api_key.id
    secret = module.kafka_app_manager_api_key.active_api_key.secret
  }
}

resource "confluent_kafka_acl" "app_consumer_read_on_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.stock_trades.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_consumer.id}"
  host          = "*"
  operation     = "READ"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.kafka_cluster.rest_endpoint
  credentials {
    key    = module.kafka_app_manager_api_key.active_api_key.id
    secret = module.kafka_app_manager_api_key.active_api_key.secret
  }
}

resource "confluent_service_account" "app_connector" {
  display_name = "tableflow_app_connector"
  description  = "Tableflow Kickstarter Service account of DataGen Source Connector to produce to the 'stock_trades' topic of the Kafka cluster"
}

resource "confluent_kafka_acl" "app_connector_describe_on_cluster" {
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }
  resource_type = "CLUSTER"
  resource_name = "kafka-cluster"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_connector.id}"
  host          = "*"
  operation     = "DESCRIBE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.kafka_cluster.rest_endpoint
  credentials {
    key    = module.kafka_app_manager_api_key.active_api_key.id
    secret = module.kafka_app_manager_api_key.active_api_key.secret
  }
}

resource "confluent_kafka_acl" "app_connector_write_on_target_topic" {
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }
  resource_type = "TOPIC"
  resource_name = confluent_kafka_topic.stock_trades.topic_name
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_connector.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.kafka_cluster.rest_endpoint
  credentials {
    key    = module.kafka_app_manager_api_key.active_api_key.id
    secret = module.kafka_app_manager_api_key.active_api_key.secret
  }
}

resource "confluent_kafka_acl" "app_connector_create_on_data_preview_topics" {
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }
  resource_type = "TOPIC"
  resource_name = "tableflow_kickstarter"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_connector.id}"
  host          = "*"
  operation     = "CREATE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.kafka_cluster.rest_endpoint
  credentials {
    key    = module.kafka_app_manager_api_key.active_api_key.id
    secret = module.kafka_app_manager_api_key.active_api_key.secret
  }
}

resource "confluent_kafka_acl" "app_connector_write_on_data_preview_topics" {
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }
  resource_type = "TOPIC"
  resource_name = "tableflow_kickstarter"
  pattern_type  = "LITERAL"
  principal     = "User:${confluent_service_account.app_connector.id}"
  host          = "*"
  operation     = "WRITE"
  permission    = "ALLOW"
  rest_endpoint = confluent_kafka_cluster.kafka_cluster.rest_endpoint
  credentials {
    key    = module.kafka_app_manager_api_key.active_api_key.id
    secret = module.kafka_app_manager_api_key.active_api_key.secret
  }
}

resource "confluent_connector" "source" {
  environment {
    id = confluent_environment.env.id
  }
  kafka_cluster {
    id = confluent_kafka_cluster.kafka_cluster.id
  }

  config_sensitive = {}

  config_nonsensitive = {
    "connector.class"          = "DatagenSource"
    "name"                     = "SampleSourceConnector"
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.app_connector.id
    "kafka.topic"              = confluent_kafka_topic.stock_trades.topic_name
    "output.data.format"       = "AVRO"
    "quickstart"               = "STOCK_TRADES"
    "tasks.max"                = "1"
  }

  depends_on = [
    confluent_kafka_acl.app_connector_describe_on_cluster,
    confluent_kafka_acl.app_connector_write_on_target_topic,
    confluent_kafka_acl.app_connector_create_on_data_preview_topics,
    confluent_kafka_acl.app_connector_write_on_data_preview_topics,
  ]
}
