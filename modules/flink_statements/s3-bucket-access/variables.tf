variable "bucket_name" {
  description = "The name of the S3 bucket to be created."
  type        = string
}

variable "principle_arns" {
  description = "The ARNs of the IAM principals to grant access to the S3 bucket."
  type        = list(string)
}

variable "actions" {
  description = "The list of actions to allow on the S3 bucket."
  type        = list(string)
}