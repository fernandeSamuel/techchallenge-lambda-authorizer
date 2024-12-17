
resource "aws_lambda_function" "cpf_validator" {
  function_name    = "cpf-validator-lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "cpf-validator.lambda_handler"
  runtime          = "python3.9"
  s3_bucket        = aws_s3_bucket.lambda_bucket.id
  s3_key           = aws_s3_object.lambda_code.key
  source_code_hash = filebase64sha256("cpf-validator.zip")

  depends_on = [
    aws_s3_object.lambda_code,
    aws_iam_role.lambda_role,
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]

  vpc_config {
    subnet_ids         = [data.terraform_remote_state.network.outputs.private_subnet_ids]
    security_group_ids = [data.terraform_remote_state.network.outputs.aws_security_group_id]
  }
}
