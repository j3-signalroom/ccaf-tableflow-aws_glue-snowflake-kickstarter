
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

output "provider_organization_name" {
  description = "The name of the organization."
  value       = local.organization_name
}

output "provider_account_name" {
  description = "The name of the account."
  value       = local.account_name
}

output "provider_user_name" {
  description = "The name of the user."
  value       = local.admin_user
}

output "provider_private_key" {
  description = "The private key for the user."
  value       = local.private_key
}

output "provider_authenticator" {
  description = "The authenticator for the user."
  value       = local.authenticator
}
output "security_admin_role_name" {
  description = "The name of the security admin role."
  value       = snowflake_account_role.security_admin_role.name
}
output "account_admin_role_name" {
  description = "The name of the account admin role."
  value       = snowflake_account_role.account_admin_role.name
}
