terraform {
  required_providers {
    confluent = {
      source = "confluentinc/confluent"
    }
  }
}

# Generate a random UUID for the statement name to ensure uniqueness.
resource "random_uuid" "flink_statement" {}

resource "confluent_flink_statement" "statement" {
  for_each = local.sorted_map

  organization {
    id = data.confluent_organization.bcp.id
  }
  environment {
    id = data.confluent_environment.catalog.id
  }
  compute_pool {
    id = data.confluent_flink_compute_pool.flink.id
  }
  principal {
    id = data.confluent_service_account.flink.id
  }

  statement_name = "${replace(each.value.file, "_", "-")}-${random_uuid.flink_statement.result}"

  statement = file("${path.module}/statements/${each.value.file}.fql")

  properties = {
    "sql.current-catalog"  = data.confluent_environment.catalog.display_name
    "sql.current-database" = data.confluent_kafka_cluster.database.display_name
  }

  rest_endpoint = var.confluent_flink_rest_endpoint

  credentials {
    key    = var.confluent_flink_api_key
    secret = var.confluent_flink_api_secret
  }
}
