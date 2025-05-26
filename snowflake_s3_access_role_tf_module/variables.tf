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

variable "base_path" {
  description = "The base path for the S3 bucket."
  type        = string
}
