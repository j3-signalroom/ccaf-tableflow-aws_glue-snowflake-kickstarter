variable "snowflake_glue_s3_role_name" {
  description = "The name of the Snowflake AWS S3 role."
  type        = string
}

variable "snowflake_aws_role_arn" {
  description = "The ARN of the Snowflake AWS role."
  type        = string
}

variable "s3_bucket_arn" {
  description = "The ARN S3 bucket."
  type        = string
}

variable "aws_s3_integration_name" {
  description = "The name of the Snowflake Storage Integration for S3."
  type        = string
}

variable "tableflow_topic_s3_base_path" {
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
  description = "The admin user for Snowflake."
  type        = string
}
variable "authenticator" {
  description = "The authenticator for Snowflake."
  type        = string
}
variable "active_private_key" {
  description = "The active private key for Snowflake."
  type        = string
  sensitive   = true
}