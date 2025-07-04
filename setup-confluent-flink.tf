# Service account to perform the task within Confluent Cloud to execute the Flink SQL statements
resource "confluent_service_account" "flink_sql_statements_runner" {
  display_name = "tableflow_flink_statements_runner"
  description  = "Service account for running Flink SQL Statements in the Kafka cluster"
}

data "confluent_organization" "signalroom" {}

resource "confluent_role_binding" "flink_sql_runner_as_flink_developer" {
    principal   = "User:${confluent_service_account.flink_sql_runner.id}"
    role_name   = "FlinkDeveloper"
    crn_pattern = data.confluent_organization.signalroom.resource_name

    depends_on = [ 
        confluent_service_account.flink_sql_runner
    ]
}

resource "confluent_role_binding" "flink_sql_runner_as_resource_owner_topic_access" {
    principal   = "User:${confluent_service_account.flink_sql_runner.id}"
    role_name   = "ResourceOwner"
    crn_pattern = "${confluent_kafka_clusterkafka_cluster.rbac_crn}/kafka=${confluent_kafka_clusterkafka_cluster.id}/topic=*"

    depends_on = [
        confluent_role_binding.flink_sql_runner_as_flink_developer
    ]
}

resource "confluent_role_binding" "flink_sql_runner_as_assigner" {
    principal   = "User:${confluent_service_account.flink_sql_runner.id}"
    role_name   = "Assigner"
    crn_pattern = "${data.confluent_organization.signalroom.resource_name}/service-account=${confluent_service_account.flink_sql_runner.id}"

    depends_on = [
        confluent_role_binding.flink_sql_runner_as_resource_owner_topic_access
    ]
}

resource "confluent_role_binding" "flink_sql_runner_schema_registry_access" {
    principal   = "User:${confluent_service_account.flink_sql_runner.id}"
    role_name   = "ResourceOwner"
    crn_pattern = "${data.confluent_schema_registry_cluster.env.resource_name}/subject=*"
    
    depends_on = [
        confluent_role_binding.flink_sql_runner_as_assigner
    ]
}

resource "confluent_role_binding" "flink_sql_runner_as_resource_owner_transactional_access" {
    principal   = "User:${confluent_service_account.flink_sql_runner.id}"
    role_name   = "ResourceOwner"
    crn_pattern = "${confluent_kafka_clusterkafka_cluster.rbac_crn}/kafka=${confluent_kafka_clusterkafka_cluster.id}/transactional-id=*"

    depends_on = [
        confluent_role_binding.flink_sql_runner_schema_registry_access
    ]
}

# https://docs.confluent.io/cloud/current/flink/get-started/quick-start-cloud-console.html#step-1-create-a-af-compute-pool
resource "confluent_flink_compute_pool" "env" {
  display_name = "tableflow_flink_statement_runner"
  cloud        = local.cloud
  region       = var.aws_region
  max_cfu      = 10
  environment {
    id = confluent_environment.tableflow_kickstarter.id
  }
  depends_on = [
    confluent_role_binding.flink_sql_statements_runner_env_admin,
    confluent_api_key.flink_sql_statements_runner_api_key,
  ]
}

# Create the Environment API Key Pairs, rotate them in accordance to a time schedule, and provide the current
# acitve API Key Pair to use
module "flink_api_key_rotation" {
    
    source  = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

    # Required Input(s)
    owner = {
        id          = confluent_service_account.flink_sql_statements_runner.id
        api_version = confluent_service_account.flink_sql_statements_runner.api_version
        kind        = confluent_service_account.flink_sql_statements_runner.kind
    }

    resource = {
        id          = data.confluent_flink_region.env.id
        api_version = data.confluent_flink_region.env.api_version
        kind        = data.confluent_flink_region.env.kind

        environment = {
            id = confluent_environment.tableflow_kickstarter.id
        }
    }

    confluent_api_key    = var.confluent_api_key
    confluent_api_secret = var.confluent_api_secret

    # Optional Input(s)
    key_display_name = "Confluent Schema Registry Cluster Service Account API Key - {date} - Managed by Terraform Cloud"
    number_of_api_keys_to_retain = var.number_of_api_keys_to_retain
    day_count = var.day_count
}

data "confluent_flink_region" "env" {
  cloud        = local.cloud
  region       = var.aws_region
}

# Create the Flink-specific API key that will be used to submit statements.
resource "confluent_api_key" "flink_sql_statements_runner_api_key" {
  display_name = "tableflow_flink_statements_runner_api_key"
  description  = "Flink API Key that is owned by 'flink_sql_statements_runner' service account"
  owner {
    id          = confluent_service_account.flink_sql_statements_runner.id
    api_version = confluent_service_account.flink_sql_statements_runner.api_version
    kind        = confluent_service_account.flink_sql_statements_runner.kind
  }
  managed_resource {
    id          = data.confluent_flink_region.env.id
    api_version = data.confluent_flink_region.env.api_version
    kind        = data.confluent_flink_region.env.kind
    
    environment {
      id = confluent_environment.tableflow_kickstarter.id
    }
  }

  depends_on = [
    confluent_environment.tableflow_kickstarter,
    confluent_service_account.flink_sql_statements_runner
  ]
}