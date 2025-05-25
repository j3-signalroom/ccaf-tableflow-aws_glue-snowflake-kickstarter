resource "aws_iam_role" "s3_role" {
  name               = "s3_role"
  assume_role_policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_iam_policy" "s3_access_policy" {
  name   = "s3_access_policy"
  policy = data.aws_iam_policy_document.s3_access_policy.json
}

resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.s3_role.name
  policy_arn = aws_iam_policy.s3_access_policy.arn
}