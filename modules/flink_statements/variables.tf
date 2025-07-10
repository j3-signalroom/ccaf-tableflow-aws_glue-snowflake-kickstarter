variable "catalog_name" {
  description = "The name of the Confluent Cloud Environment."
  type        = string
}

variable "database_name" {
  description = "The name of the Confluent Cloud Kafka Cluster."
  type        = string
}

variable "statements" {
  description = "A list of Flink SQL statements to process a particular Flink job."
  type        = list(object({
      id   = number
      file = string
  }))
}

variable "confluent_flink_compute_pool_name" {
  description = "The name of the Confluent Flink compute flink."
  type        = string
}

variable "confluent_flink_rest_endpoint" {
  description = "The REST endpoint for the Confluent Flink service."
  type        = string
}

variable "confluent_flink_api_key" {
  description = "The API key for the Confluent Flink service."
  type        = string
}

variable "confluent_flink_api_secret" {
  description = "The API secret for the Confluent Flink service."
  type        = string
}

variable "confluent_flink_service_account_name" {
  description = "The name of the Confluent Flink service account."
  type        = string
}