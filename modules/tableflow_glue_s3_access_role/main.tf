resource "aws_iam_role" "tableflow_glue_s3_role" {
  name               = var.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.tableflow_glue_s3_policy.json
}

resource "aws_iam_policy" "tableflow_glue_s3_access_policy" {
  name   = "tableflow_glue_s3_access_policy"
  policy = data.aws_iam_policy_document.tableflow_glue_s3_access_policy.json
}

resource "aws_iam_role_policy_attachment" "tableflow_glue_s3_policy_attachment" {
  role       = aws_iam_role.tableflow_glue_s3_role.name
  policy_arn = aws_iam_policy.tableflow_glue_s3_access_policy.arn
}