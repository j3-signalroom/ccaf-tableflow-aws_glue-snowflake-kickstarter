# Create the Snowflake user RSA keys pairs
module "snowflake_user_rsa_key_pairs_rotation" {   
    source  = "github.com/j3-signalroom/iac-snowflake-user-rsa_key_pairs_rotation-tf_module"

    # Required Input(s)
    aws_region                = var.aws_region
    aws_account_id            = var.aws_account_id
    snowflake_account         = jsondecode(data.aws_secretsmanager_secret_version.admin_public_keys.secret_string)["account"]
    service_account_user      = var.secrets_insert

    # Optional Input(s)
    secret_insert             = var.secrets_insert
    day_count                 = var.day_count
    aws_lambda_memory_size    = var.aws_lambda_memory_size
    aws_lambda_timeout        = var.aws_lambda_timeout
    aws_log_retention_in_days = var.aws_log_retention_in_days
}


provider "snowflake" {
  alias             = "security_admin"
  role              = "SECURITYADMIN"
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.admin_user
  authenticator     = local.authenticator
  private_key       = local.private_key
}

resource "snowflake_account_role" "security_admin_role" {
  provider = snowflake.security_admin
  name     = "${upper(var.secrets_insert)}_ROLE"
}

resource "snowflake_user" "user" {
  provider          = snowflake.security_admin
  name              = var.user_name
  default_warehouse = var.warehouse_name
  default_role      = snowflake_account_role.security_admin_role.name
  default_namespace = "${var.database_name}.${var.schema_name}"

  # Setting the attributes to `null`, effectively unsets the attribute
  # Refer to this link `https://docs.snowflake.com/en/user-guide/key-pair-auth#configuring-key-pair-rotation`
  # for more information
  rsa_public_key    = var.active_rsa_public_key_number == 1 ? local.rsa_public_key_1 : null
  rsa_public_key_2  = var.active_rsa_public_key_number == 2 ? local.rsa_public_key_2 : null

  depends_on = [ 
    snowflake_account_role.security_admin_role
  ]
}

resource "snowflake_grant_privileges_to_account_role" "warehouse" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.security_admin_role.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = var.warehouse_name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.security_admin_role 
  ]
}

resource "snowflake_grant_privileges_to_account_role" "user" {
  provider          = snowflake.security_admin
  privileges        = ["MONITOR"]
  account_role_name = snowflake_account_role.security_admin_role.name  
  on_account_object {
    object_type = "USER"
    object_name = var.user_name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.security_admin_role 
  ]
}

resource "snowflake_grant_account_role" "user_security_admin" {
  provider  = snowflake.security_admin
  role_name = snowflake_account_role.security_admin_role.name
  user_name = var.user_name

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.security_admin_role 
  ]
}

provider "snowflake" {
  alias             = "account_admin"
  role              = "ACCOUNTADMIN"
  organization_name = local.organization_name
  account_name      = local.account_name
  user              = local.admin_user
  authenticator     = "SNOWFLAKE_JWT"
  private_key       = local.private_key

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

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role 
  ]
}

resource "snowflake_grant_privileges_to_account_role" "schema" {
  provider          = snowflake.account_admin
  privileges        = ["CREATE FILE FORMAT", "USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_schema {
    schema_name = "${var.database_name}.${var.schema_name}"
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role 
  ]
}

resource "snowflake_grant_privileges_to_account_role" "integration_grant" {
  provider          = snowflake.account_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.account_admin_role.name
  on_account_object {
    object_type = "INTEGRATION"
    object_name = var.aws_s3_integration_name
  }

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role 
  ]
}

resource "snowflake_grant_account_role" "user_account_admin" {
  provider  = snowflake.account_admin
  role_name = snowflake_account_role.account_admin_role.name
  user_name = var.user_name

  depends_on = [ 
    snowflake_user.user,
    snowflake_account_role.account_admin_role 
  ]
}
