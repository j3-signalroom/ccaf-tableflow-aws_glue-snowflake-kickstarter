provider "aws" {
    region     = var.aws_region
    access_key = var.aws_access_key_id
    secret_key = var.aws_secret_access_key
    token      = var.aws_session_token
}

provider "confluent" {
  cloud_api_key    = var.confluent_api_key
  cloud_api_secret = var.confluent_api_secret
}


# `ACCOUNTADMIN` role is required to create the external volume.
provider "snowflake" {
  alias             = "account_admin"
  role              = "ACCOUNTADMIN"
  organization_name = local.snowflake_organization_name
  account_name      = local.snowflake_account_name
  user              = local.snowflake_admin_user
  authenticator     = local.snowflake_authenticator
  private_key       = local.snowflake_active_private_key

  preview_features_enabled = [
    "snowflake_external_volume_resource",
    "snowflake_storage_integration_resource"
  ]
}
# The SECURITYADMIN (Security Administrator) is responsible for users, roles and privileges.
# All roles, users and privileges should be owned and created by the security administrator.
provider "snowflake" {
  alias             = "security_admin"
  role              = "SECURITYADMIN"
  organization_name = local.snowflake_organization_name
  account_name      = local.snowflake_account_name
  user              = local.snowflake_admin_user
  authenticator     = local.snowflake_authenticator
  private_key       = local.snowflake_active_private_key
}

# The SYSADMIN (Systems Admin) oversees creating objects inside Snowflake.
provider "snowflake" {
  role              = "SYSADMIN"
  organization_name = local.snowflake_organization_name
  account_name      = local.snowflake_account_name
  user              = local.snowflake_admin_user
  authenticator     = local.snowflake_authenticator
  private_key       = local.snowflake_active_private_key
}
