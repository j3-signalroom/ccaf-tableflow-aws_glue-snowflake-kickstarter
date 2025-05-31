provider "snowflake" {
  role              = "ACCOUNTADMIN"
  organization_name = var.organization_name
  account_name      = var.account_name
  user              = var.admin_user
  authenticator     = var.authenticator
  private_key       = var.active_private_key

  # Enable preview features
  preview_features_enabled = [
    "snowflake_storage_integration_resource"
  ]
}
