data "archive_file" "lambda_auth_src" {
  type        = "zip"
  output_path = "${path.module}/lambda_edge_auth.zip"
  source_file = "${path.module}/lambda_edge_auth_fxn/edge_auth.js"
}


resource "aws_iam_role_policy" "lambda_execution" {
  name_prefix = "lambda-execution-policy-"
  role        = aws_iam_role.lambda_execution.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:CreateLogGroup"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "lambda_execution" {
  name_prefix        = "lambda-execution-role-"
  description        = "Managed by Terraform"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "edgelambda.amazonaws.com",
          "lambda.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "cf_distrib_edge_auth" {
  function_name    = "lambda_edge_auth"
  handler          = "edge_auth.handler"
  source_code_hash = data.archive_file.lambda_auth_src.output_base64sha256
  filename         = "${path.module}/lambda_edge_auth.zip"
  role             = aws_iam_role.lambda_execution.arn
  publish          = true
  runtime          = "nodejs10.x"
}