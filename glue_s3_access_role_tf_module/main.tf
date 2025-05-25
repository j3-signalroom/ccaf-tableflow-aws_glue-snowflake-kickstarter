
# Glue Role and Policy
resource "aws_iam_role" "glue_s3_role" {
  name               = "glue_s3_role"
  assume_role_policy = data.aws_iam_policy_document.glue_s3_policy.json
}

resource "aws_iam_policy" "glue_s3_access_policy" {
  name = "glue_s3_access_policy"
  policy = data.aws_iam_policy_document.glue_s3_access_policy.json
}

resource "aws_iam_role_policy_attachment" "glue_s3_policy_attachment" {
  role       = aws_iam_role.glue_s3_role.name
  policy_arn = aws_iam_policy.glue_s3_access_policy.arn
}
