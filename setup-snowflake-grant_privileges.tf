resource "snowflake_grant_privileges_to_account_role" "user_all_privileges" {
  provider          = snowflake.security_admin
  privileges        = ["ALL PRIVILEGES"]
  account_role_name = snowflake_account_role.security_admin_role.name  
  on_account_object {
    object_type = "USER"
    object_name = local.user_name
  }

  depends_on = [ 
    snowflake_grant_account_role.user_security_admin 
  ]
}

resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.security_admin_role.name
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = local.warehouse_name
  }

  depends_on = [ 
    snowflake_grant_account_role.user_security_admin,
    snowflake_warehouse.tableflow_kickstarter
  ]
}

resource "snowflake_grant_privileges_to_account_role" "database_usage" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.security_admin_role.name
  on_account_object {
    object_type = "DATABASE"
    object_name = local.database_name
  }

  depends_on = [ 
    snowflake_grant_account_role.user_security_admin,
    snowflake_database.tableflow_kickstarter
  ]
}

resource "snowflake_grant_privileges_to_account_role" "integration_usage" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.security_admin_role.name
  on_account_object {
    object_type = "INTEGRATION"
    object_name = local.aws_s3_integration_name
  }

  depends_on = [ 
    snowflake_grant_account_role.user_security_admin
  ]
}

resource "snowflake_grant_privileges_to_account_role" "schema_all_privileges" {
  provider          = snowflake.security_admin
  privileges        = ["ALL PRIVILEGES"]
  account_role_name = snowflake_account_role.security_admin_role.name
  on_schema {
    schema_name = "${local.database_name}.${local.schema_name}"
  }

  depends_on = [
    snowflake_grant_account_role.user_security_admin
  ]
}

# Emits GRANT ALL PRIVILEGES ON FUTURE FILE FORMATS IN SCHEMA <schema_name> TO ROLE <security_admin_role>;
resource "snowflake_grant_privileges_to_account_role" "future_file_format_all_privileges" {
  provider          = snowflake.security_admin
  privileges        = ["ALL PRIVILEGES"]
  account_role_name = snowflake_account_role.security_admin_role.name
  on_schema_object {
    future {
        object_type_plural = "FILE FORMATS"
        in_schema = "${local.database_name}.${local.schema_name}"
    }
  }

  depends_on = [
    snowflake_grant_account_role.user_security_admin
  ]
}

# Emits GRANT USAGE ON FUTURE STAGES IN SCHEMA <schema_name> TO ROLE <security_admin_role>;
resource "snowflake_grant_privileges_to_account_role" "future_stage_usage" {
  provider          = snowflake.security_admin
  privileges        = ["USAGE"]
  account_role_name = snowflake_account_role.security_admin_role.name
  on_schema_object {
    future {
        object_type_plural = "STAGES"
        in_schema = "${local.database_name}.${local.schema_name}"
    }
  }

  depends_on = [
    snowflake_grant_account_role.user_security_admin
  ]
}
