resource "confluent_provider_integration" "main" {
  environment {
    id = confluent_environment.env.id
  }
  aws {
    customer_role_arn = local.snowflake_aws_role_arn
  }
  display_name = "provider_integration_main"
}