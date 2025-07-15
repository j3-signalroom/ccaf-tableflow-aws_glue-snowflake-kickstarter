data "confluent_organization" "signalroom" {}

data "confluent_environment" "catalog" {
  display_name = var.catalog_name
}

data "confluent_kafka_cluster" "database" {
  display_name = var.database_name
  environment {
    id = data.confluent_environment.catalog.id
  }
}

data "confluent_flink_compute_pool" "flink" {
  display_name = var.confluent_flink_compute_pool_name
  environment {
    id = data.confluent_environment.catalog.id
  }
}

data "confluent_flink_region" "flink" {
  cloud   = data.confluent_flink_compute_pool.flink.cloud
  region  = data.confluent_flink_compute_pool.flink.region
}

data "confluent_service_account" "flink" {
    display_name = var.confluent_flink_service_account_name
}

locals {
  sorted_map = { for key, value in var.statements : format("%.2d", key) => value }
}
