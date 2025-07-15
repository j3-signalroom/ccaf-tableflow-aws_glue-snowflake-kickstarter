# Service account to perform the task within Confluent Cloud to execute the Flink SQL statements
resource "confluent_service_account" "flink_sql_runner" {
  display_name = local.service_account_name
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
    crn_pattern = "${confluent_kafka_cluster.kafka_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.kafka_cluster.id}/topic=*"

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
    crn_pattern = "${confluent_kafka_cluster.kafka_cluster.rbac_crn}/kafka=${confluent_kafka_cluster.kafka_cluster.id}/transactional-id=*"

    depends_on = [
        confluent_role_binding.flink_sql_runner_schema_registry_access
    ]
}

resource "confluent_flink_compute_pool" "env" {
  display_name = "tableflow_flink_statement_runner"
  cloud        = local.cloud
  region       = var.aws_region
  max_cfu      = 10
  environment {
    id = confluent_environment.tableflow_kickstarter.id
  }
  depends_on = [
    confluent_role_binding.flink_sql_runner_as_resource_owner_transactional_access,
    confluent_api_key.flink_sql_runner_api_key,
  ]
}

# Create the Environment API Key Pairs, rotate them in accordance to a time schedule, and provide the current
# acitve API Key Pair to use
module "flink_api_key_rotation" {
    source  = "github.com/j3-signalroom/iac-confluent-api_key_rotation-tf_module"

    # Required Input(s)
    owner = {
        id          = confluent_service_account.flink_sql_runner.id
        api_version = confluent_service_account.flink_sql_runner.api_version
        kind        = confluent_service_account.flink_sql_runner.kind
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
resource "confluent_api_key" "flink_sql_runner_api_key" {
  display_name = "tableflow_flink_statements_runner_api_key"
  description  = "Flink API Key that is owned by 'flink_sql_runner' service account"
  owner {
    id          = confluent_service_account.flink_sql_runner.id
    api_version = confluent_service_account.flink_sql_runner.api_version
    kind        = confluent_service_account.flink_sql_runner.kind
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
    confluent_service_account.flink_sql_runner
  ]
}

module "drop" {
	source                               = "./modules/flink_statements"
	catalog_name                         = confluent_environment.tableflow_kickstarter.display_name
	database_name                        = confluent_kafka_cluster.kafka_cluster.display_name
	statements						               = var.drop_flink_statements
	confluent_flink_compute_pool_name    = confluent_flink_compute_pool.env.display_name
	confluent_flink_rest_endpoint        = local.flink_rest_endpoint
	confluent_flink_api_key              = module.flink_api_key_rotation.active_api_key.id
	confluent_flink_api_secret           = module.flink_api_key_rotation.active_api_key.secret
	confluent_flink_service_account_name = confluent_service_account.flink_sql_runner.display_name

	providers = {
	  confluent = confluent
	}

	depends_on = [ 
		confluent_tableflow_topic.stock_trades,
    confluent_flink_compute_pool.env,
    confluent_service_account.flink_sql_runner,
    module.flink_api_key_rotation
	]
}

module "create_set_1" {
	source                               = "./modules/flink_statements"
	catalog_name                         = confluent_environment.tableflow_kickstarter.display_name
	database_name                        = confluent_kafka_cluster.kafka_cluster.display_name
	statements						               = var.create_set_1_flink_statements
	confluent_flink_compute_pool_name    = confluent_flink_compute_pool.env.display_name
	confluent_flink_rest_endpoint        = local.flink_rest_endpoint
	confluent_flink_api_key              = module.flink_api_key_rotation.active_api_key.id
	confluent_flink_api_secret           = module.flink_api_key_rotation.active_api_key.secret
	confluent_flink_service_account_name = confluent_service_account.flink_sql_runner.display_name

	providers = {
	  confluent = confluent
	}

	depends_on = [
		module.drop
	]
}
