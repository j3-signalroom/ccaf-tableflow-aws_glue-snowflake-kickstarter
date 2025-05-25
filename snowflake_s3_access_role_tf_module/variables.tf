variable "s3_bucket_arn" {
  description = "The ARN S3 bucket."
  type        = string
}

variable "external_id" {
  description = "The external ID of the Storage Integration. It's the unique external ID that Snowflake uses when it assumes the IAM role in your Amazon Web Services (AWS) account."
  type        = string
}

variable "iam_user_arn" {
  description = "The IAM role ARN used in Storage Integration internally."
  type        = string
}
