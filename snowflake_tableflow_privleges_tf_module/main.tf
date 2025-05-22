provider "snowflake" {
  alias             = "security_admin"
  role              = "SECURITYADMIN"
  organization_name = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[0]}"
  account_name      = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[1]}"
  user              = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["admin_user"]
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["active_rsa_public_key_number"] == 1 ? data.aws_secretsmanager_secret_version.admin_private_key_1.secret_string : data.aws_secretsmanager_secret_version.admin_private_key_2.secret_string
}

resource "snowflake_account_role" "security_admin_role" {
  provider = snowflake.security_admin
  name     = "${upper(var.secrets_insert)}_ROLE"
}

resource "snowflake_grant_privileges_to_account_role" "warehouse" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.security_admin_role.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.warehouse_name
  }

  depends_on = [ snowflake_account_role.security_admin_role ]
}

resource "snowflake_grant_privileges_to_account_role" "user" {
  provider          = snowflake.security_admin
  privileges        = ["MONITOR"]
  account_role_name = snowflake_account_role.security_admin_role.name  
  on_account_object {
    object_type = "USER"
    object_name = var.user_name
  }

  depends_on = [ snowflake_account_role.security_admin_role ]
}

resource "snowflake_grant_account_role" "user_security_admin" {
  provider  = snowflake.security_admin
  role_name = snowflake_account_role.security_admin_role.name
  user_name = var.user_name

  depends_on = [ snowflake_account_role.security_admin_role ]
}

provider "snowflake" {
  alias             = "account_admin"
  role              = "ACCOUNTADMIN"
  organization_name = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[0]}"
  account_name      = "${split("-", jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"])[1]}"
  user              = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["admin_user"]
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["active_rsa_public_key_number"] == 1 ? data.aws_secretsmanager_secret_version.admin_private_key_1.secret_string : data.aws_secretsmanager_secret_version.admin_private_key_2.secret_string

  # Enable preview features
  preview_features_enabled = [
    "snowflake_storage_integration_resource"
  ]
}

resource "snowflake_account_role" "account_admin_role" {
  provider = snowflake.account_admin
  name     = "${upper(var.secrets_insert)}_ADMIN_ROLE"
}

resource "snowflake_grant_privileges_to_account_role" "database" {
  provider          = snowflake.account_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_account_object {
    object_type = "DATABASE"
    object_name = var.database_name
  }

  depends_on = [ snowflake_account_role.account_admin_role ]
}

resource "snowflake_grant_privileges_to_account_role" "schema" {
  provider          = snowflake.account_admin
  privileges        = ["CREATE FILE FORMAT", "USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_schema {
    schema_name = "${var.database_name}.${var.schema_name}"
  }

  depends_on = [ snowflake_account_role.account_admin_role ]
}

resource "snowflake_grant_privileges_to_account_role" "integration_grant" {
  provider          = snowflake.account_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_account_object {
    object_type = "INTEGRATION"
    object_name = var.aws_s3_integration_name
  }

  depends_on = [ snowflake_account_role.account_admin_role ]
}

resource "snowflake_grant_account_role" "user_account_admin" {
  provider  = snowflake.account_admin
  role_name = snowflake_account_role.account_admin_role.name
  user_name = var.user_name

  depends_on = [ snowflake_account_role.account_admin_role ]
}
