resource "confluent_environment" "tableflow_kickstarter" {
  display_name = "${local.secrets_insert}"

  stream_governance {
    package = "ESSENTIALS"
  }
}