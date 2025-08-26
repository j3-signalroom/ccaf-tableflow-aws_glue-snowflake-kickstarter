output "bucket_policy_id" {
  description = "The ID of the S3 bucket policy."
  value       = aws_s3_bucket_policy.this.id
}