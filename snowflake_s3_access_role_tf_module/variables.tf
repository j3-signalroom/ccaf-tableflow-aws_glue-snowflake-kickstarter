variable "s3_bucket_arn" {
  description = "The ARN S3 bucket."
  type        = string
}

variable "aws_s3_integration_name" {
  description = "The name of the Snowflake Storage Integration for S3."
  type        = string
}

variable "base_path" {
  description = "The base path for the S3 bucket."
  type        = string
}

variable "organization_name" {
  description = "The name of the Snowflake organization."
  type        = string
}

variable "account_name" {
  description = "The name of the Snowflake account."
  type        = string
}

variable "admin_user" {
  description = "The Snowflake admin user."
  type        = string
}

variable "authenticator" {
  description = "The Snowflake authenticator."
  type        = string
}


variable "active_private_key" {
  description = "The active private key for Snowflake authentication."
  type        = string
  sensitive   = true
}

variable "snowflake_s3_role_arn" {
  description = "The ARN of the Snowflake S3 role."
  type        = string
}