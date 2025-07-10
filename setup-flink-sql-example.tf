module "drop" {
	source                               = "./modules/flink_statements"
	catalog_name                         = confluent_environment.tableflow_kickstarter.display_name
	database_name                        = confluent_kafka_cluster.kafka_cluster.display_name
	statements						     = var.drop_flink_statements
	confluent_flink_compute_pool_name    = confluent_flink_compute_pool.env.display_name
	confluent_flink_rest_endpoint        = confluent_flink_compute_pool.env.rest_endpoint
	confluent_flink_api_key              = confluent_api_key.flink_api_key.id
	confluent_flink_api_secret           = confluent_api_key.flink_api_key.secret
	confluent_flink_service_account_name = local.service_account_name

	providers = {
	  confluent = confluent
	}

	depends_on = [ 
		confluent_api_key.flink_api_key
	]
}

module "create_set_1" {
	source                               = "./modules/flink_statements"
	catalog_name                         = confluent_environment.tableflow_kickstarter.display_name
	database_name                        = confluent_kafka_cluster.kafka_cluster.display_name
	statements						     = var.drop_flink_statements
	confluent_flink_compute_pool_name    = confluent_flink_compute_pool.env.display_name
	confluent_flink_rest_endpoint        = confluent_flink_compute_pool.env.rest_endpoint
	confluent_flink_api_key              = confluent_api_key.flink_api_key.id
	confluent_flink_api_secret           = confluent_api_key.flink_api_key.secret
	confluent_flink_service_account_name = local.service_account_name

	providers = {
	  confluent = confluent
	}

	depends_on = [
		module.drop 
	]
}
