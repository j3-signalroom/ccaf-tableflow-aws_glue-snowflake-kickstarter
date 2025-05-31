# This Terraform configuration is temporary, until Confluent exposes the table_path
# in the `confluent_tableflow_topic` resource. It is used to retrieve the Tableflow
# Topic's table_path and tableflow_topic_s3_base_path from the

# Perform a GET request to the Tableflow API to retrieve Tableflow info
# from the enabled Tableflow Kafka Topic.
data "http" "tableflow_topic" {
  url    = "https://api.confluent.cloud/tableflow/v1/tableflow-topics/${confluent_kafka_topic.stock_trades.topic_name}?environment=${confluent_environment.tableflow_kickstarter.id}&spec.kafka_cluster=${confluent_kafka_cluster.kafka_cluster.id}"
  method = "GET"

  request_headers = {
    Authorization = "Basic ${base64encode("${module.tableflow_api_key.active_api_key.id}:${module.tableflow_api_key.active_api_key.secret}")}"
    Accept        = "application/json"
  }

  retry {
    attempts     = 5
    min_delay_ms = 5000
    max_delay_ms = 9000 
  }

  depends_on = [ 
    confluent_tableflow_topic.stock_trades 
  ]
}

# Ensure that the Tableflow Topic GET RESTful API call made before proceeding
# on to the local variable declaration below.
resource "null_resource" "after_tableflow_topic" {
  triggers = {
    response = data.http.tableflow_topic.response_body
  }
}

# Local that now "depends on" the null-resource via its trigger to get the 
# Tableflow Topic's tableflow_topic_s3_table_path and 
# tableflow_topic_s3_base_path from the response body.
locals {
  response_body                 = jsondecode(null_resource.after_tableflow_topic.triggers["response"])
  tableflow_topic_s3_table_path = local.response_body["spec"]["storage"]["table_path"]
  part_before_v1                = split("/v1/", local.tableflow_topic_s3_table_path)
  tableflow_topic_s3_base_path  = "${local.part_before_v1[0]}/v1/"
}
