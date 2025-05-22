
output "user_name" {
  description = "The name of the Snowflake user."
  value        = var.user_name
}

output "warehouse_name" {
  description = "The name of the Snowflake warehouse."
  value        = var.warehouse_name
}

output "database_name" {
  description = "The name of the Snowflake database."
  value        = var.database_name
}

output "schema_name" {
  description = "The name of the Snowflake schema."
  value        = var.schema_name
}

output "aws_s3_integration_name" {
  description = "The name of the AWS S3 integration."
  value        = var.aws_s3_integration_name
}

output "security_admin_provider" {
  description = "The Snowflake provider for the security admin role."
  value       = provider.snowflake.security_admin
}
output "account_admin_provider" {
  description = "The Snowflake provider for the account admin role."
  value       = provider.snowflake.account_admin
}

output "provider_organization_name" {
  description = "The name of the organization."
  value       = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[0]}"
}

output "provider_account_name" {
  description = "The name of the account."
  value       = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[1]}"
}

output "provider_user_name" {
  description = "The name of the user."
  value       = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["admin_user"]
}

output "provider_private_key" {
  description = "The private key for the user."
  value       = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["active_rsa_public_key_number"] == 1 ? data.aws_secretsmanager_secret_version.admin_private_key_1.secret_string : data.aws_secretsmanager_secret_version.admin_private_key_2.secret_string
}
