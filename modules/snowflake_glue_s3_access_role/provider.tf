# `ACCOUNTADMIN` role is required to create the storage integration.
provider "snowflake" {
  role              = "ACCOUNTADMIN"
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.admin_user
  authenticator     = var.authenticator
  private_key       = var.active_private_key

  # Enable preview features
  preview_features_enabled = [
    "snowflake_storage_integration_resource",
  ]
}

# The SECURITYADMIN (Security Administrator) is responsible for users, roles and privileges.
# All roles, users and privileges should be owned and created by the security administrator.
provider "snowflake" {
  alias             = "security_admin"
  role              = "SECURITYADMIN"
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.admin_user
  authenticator     = var.authenticator
  private_key       = var.active_private_key

  # Enable preview features
  preview_features_enabled = [
    "snowflake_storage_integration_resource",
  ]
}