resource "aws_s3_bucket_policy" "this" {
    bucket = var.bucket_name

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    AWS = var.principle_arns
                }
                Action = var.actions
                Resource = "${var.bucket_name}/*"
            }
        ]
    })
}
