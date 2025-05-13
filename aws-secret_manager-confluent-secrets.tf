# Create the Schema Registry Cluster Secrets: API Key Pair and REST endpoint for Python client
resource "aws_secretsmanager_secret" "schema_registry_cluster_api_key_python_client" {
    name = "${local.confluent_secrets_path_prefix}/schema_registry_cluster/python_client"
    description = "Schema Registry Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "schema_registry_cluster_api_key_python_client" {
    secret_id     = aws_secretsmanager_secret.schema_registry_cluster_api_key_python_client.id
    secret_string = jsonencode({"schema.registry.basic.auth.credentials.source": "USER_INFO",
                                "schema.registry.basic.auth.user.info": "${module.schema_registry_cluster_api_key_rotation.active_api_key.id}:${module.schema_registry_cluster_api_key_rotation.active_api_key.secret}",
                                "schema.registry.url": "${data.confluent_schema_registry_cluster.env.rest_endpoint}"})
}

# Create the Kafka Cluster Secrets: API Key Pair, JAAS (Java Authentication and Authorization) representation
# for Python client, bootstrap server URI and REST endpoint
resource "aws_secretsmanager_secret" "app_manager_kafka_cluster_api_key" {
    name = "${local.confluent_secrets_path_prefix}/kafka_cluster/app_manager/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "app_manager_kafka_cluster_api_key" {
    secret_id     = aws_secretsmanager_secret.app_manager_kafka_cluster_api_key.id
    secret_string = jsonencode({"sasl.username": "${module.app_manager_kafka_api_key.active_api_key.id}",
                                "sasl.password": "${module.app_manager_kafka_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.kafka_cluster.bootstrap_endpoint, "SASL_SSL://", "")})
}

resource "aws_secretsmanager_secret" "app_consumer_kafka_api_key" {
    name = "${local.confluent_secrets_path_prefix}/kafka_cluster/app_consumer/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "app_consumer_kafka_api_key" {
    secret_id     = aws_secretsmanager_secret.app_consumer_kafka_api_key.id
    secret_string = jsonencode({"sasl.username": "${module.app_consumer_kafka_api_key.active_api_key.id}",
                                "sasl.password": "${module.app_consumer_kafka_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.kafka_cluster.bootstrap_endpoint, "SASL_SSL://", "")})
}

resource "aws_secretsmanager_secret" "app_producer_kafka_api_key" {
    name = "${local.confluent_secrets_path_prefix}/kafka_cluster/app_producer/python_client"
    description = "Kafka Cluster secrets for Python client"
}

resource "aws_secretsmanager_secret_version" "app_producer_kafka_api_key" {
    secret_id     = aws_secretsmanager_secret.app_producer_kafka_api_key.id
    secret_string = jsonencode({"sasl.username": "${module.app_producer_kafka_api_key.active_api_key.id}",
                                "sasl.password": "${module.app_producer_kafka_api_key.active_api_key.secret}",
                                "bootstrap.servers": replace(confluent_kafka_cluster.kafka_cluster.bootstrap_endpoint, "SASL_SSL://", "")})
}

resource "aws_secretsmanager_secret" "flink_api_key" {
    name = "${local.confluent_secrets_path_prefix}/flink"
    description = "Flink Compute Pool secrets"
}

resource "aws_secretsmanager_secret_version" "flink_api_key" {
    secret_id     = aws_secretsmanager_secret.flink_api_key.id
    secret_string = jsonencode({"api.key": "${module.flink_api_key_rotation.active_api_key.id}",
                                "api.key.secret": "${module.flink_api_key_rotation.active_api_key.secret}",
                                "compute.pool.id": "${confluent_flink_compute_pool.env.id}",
                                "principal.id": "${confluent_service_account.flink_sql_statements_runner.id}"})
}

resource "aws_secretsmanager_secret" "tableflow_api_key" {
    name = "${local.confluent_secrets_path_prefix}/tableflow"
    description = "Tableflow secrets"
}

resource "aws_secretsmanager_secret_version" "tableflow_api_key" {
    secret_id     = aws_secretsmanager_secret.tableflow_api_key.id
    secret_string = jsonencode({"api.key": "${module.tableflow_api_key.active_api_key.id}",
                                "api.key.secret": "${module.tableflow_api_key.active_api_key.secret}",
                                "environment.id": "${confluent_environment.env.id}",
                                "kafka.cluster.id": "${confluent_kafka_cluster.kafka_cluster.id}"})
}