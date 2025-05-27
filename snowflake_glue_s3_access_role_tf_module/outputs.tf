output "aws_iam_user_arn" {
  description = "The ARN of the Snowflake S3 access role."
  value       = snowflake_storage_integration.aws_s3_integration.storage_aws_iam_user_arn
}

output "aws_external_id" {
  description = "The AWS external ID for the Snowflake S3 access role."
  value       = snowflake_storage_integration.aws_s3_integration.storage_aws_external_id
}