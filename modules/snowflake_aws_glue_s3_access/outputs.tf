output "s3_external_id" {
  description = "The AWS external ID for the Snowflake S3 access role."
  value       = snowflake_external_volume.external_volume.storage_location[0].storage_aws_external_id
}