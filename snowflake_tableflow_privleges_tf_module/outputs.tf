
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
  value       = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[0]}"
}

output "provider_account_name" {
  description = "The name of the account."
  value       = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[1]}"
}

output "provider_snowflake_account" {
  description = "The Snowflake account identifier."
  value       = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"]
}

output "provider_user_name" {
  description = "The name of the user."
  value       = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["admin_user"]
}

output "provider_private_key" {
  description = "The private key for the user."
  value       = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["active_rsa_public_key_number"] == 1 ? data.aws_secretsmanager_secret_version.admin_private_key_1.secret_string : data.aws_secretsmanager_secret_version.admin_private_key_2.secret_string
}

output "security_admin_role_name" {
  description = "The name of the security admin role."
  value       = snowflake_account_role.security_admin_role.name
}
output "account_admin_role_name" {
  description = "The name of the account admin role."
  value       = snowflake_account_role.account_admin_role.name
}

output "rsa_public_key_1" {
  description = "The first RSA public key."
  value       = jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_1"]
}

output "rsa_public_key_2" {
  description = "The second RSA public key."
  value       = jsondecode(data.aws_secretsmanager_secret_version.svc_public_keys.secret_string)["rsa_public_key_2"]
}
