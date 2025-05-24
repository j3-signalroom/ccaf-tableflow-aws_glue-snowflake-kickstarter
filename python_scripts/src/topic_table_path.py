#!/usr/bin/env python3
import sys
import json
import logging

from cc_clients_python_lib.tableflow_client import TableflowClient, TABLEFLOW_CONFIG


__copyright__  = "Copyright (c) 2025 Jeffrey Jonathan Jennings"
__credits__    = ["Jeffrey Jonathan Jennings (J3)"]
__maintainer__ = "Jeffrey Jonathan Jennings (J3)"
__email__      = "j3@thej3.com"
__status__     = "dev"


# Configure the logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

def main():
    # Read the parameters from stdin.
    params = json.load(sys.stdin)
    kafka_topic_name = params.get("kafka_topic_name", "")
    kafka_cluster_id = params.get("kafka_cluster_id", "")
    environment_id = params.get("environment_id", "")
    tableflow_config = {}
    tableflow_config[TABLEFLOW_CONFIG["tableflow_api_key"]] = params.get("tableflow_api_key", "")
    tableflow_config[TABLEFLOW_CONFIG["tableflow_api_secret"]] = params.get("tableflow_api_secret", "")

    # Instantiate the TableflowClient class.
    tableflow_client = TableflowClient(tableflow_config)

    # Get the table path for the given Kafka topic.
    http_status_code, error_message, table_path = tableflow_client.get_tableflow_topic_table_path(kafka_topic_name, environment_id, kafka_cluster_id)

    # Log the results.
    output = {
      "table_path": table_path,
      "error_message": error_message,
      "http_status_code": http_status_code
    }

    # Print the output as JSON to stdout.
    json.dump(output, sys.stdout)


if __name__ == "__main__":
    main()
