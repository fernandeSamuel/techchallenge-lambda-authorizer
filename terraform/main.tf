resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Criação do HTTP API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "http-api-cpf-validator"
  protocol_type = "HTTP"
  description   = "HTTP API Gateway integrado com Lambda CPF Validator"
}

# Integração do HTTP API Gateway com a Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.http_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.cpf_validator.invoke_arn
  payload_format_version = "2.0"

  depends_on = [aws_lambda_function.cpf_validator]
}

# Configuração da rota POST /CPFAuth
resource "aws_apigatewayv2_route" "cpf_auth_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /auth"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

  depends_on = [aws_apigatewayv2_integration.lambda_integration]
}

# Permissão para o HTTP API Gateway invocar a Lambda
resource "aws_lambda_permission" "http_api_gateway_invoke_lambda" {
  statement_id  = "AllowHTTPApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cpf_validator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"

  depends_on = [aws_apigatewayv2_api.http_api]
}

# Deployment do HTTP API Gateway
resource "aws_apigatewayv2_stage" "dev_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "dev"
  auto_deploy = true

  depends_on = [aws_apigatewayv2_route.cpf_auth_route]
}

# Bucket S3 para o código Lambda
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "lambda-code-bucket-cpf-validator-${random_string.suffix.result}"

  tags = {
    Name = "LambdaCodeBucket"
  }
}

# Upload do código Lambda no S3
resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "cpf-validator.zip"
  source = "cpf-validator.zip"
}

# Política do S3 para a Lambda acessar o código
resource "aws_s3_bucket_policy" "lambda_bucket_policy" {
  bucket = aws_s3_bucket.lambda_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowLambdaRead",
        Effect    = "Allow",
        Principal = { Service = "lambda.amazonaws.com" },
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.lambda_bucket.arn}/*"
      }
    ]
  })
}

# IAM Role para a Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role_http_api"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

# Política de execução básica para Lambda
resource "aws_iam_policy" "lambda_execution_policy" {
  name        = "lambda_execution_policy_http_api"
  description = "Policy for Lambda execution"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Anexar política à Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
}

# Lambda Function
resource "aws_lambda_function" "cpf_validator" {
  function_name = "cpf-validator-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "cpf-validator.lambda_handler"
  runtime       = "python3.9"
  s3_bucket     = aws_s3_bucket.lambda_bucket.id
  s3_key        = aws_s3_object.lambda_code.key
  source_code_hash = filebase64sha256("cpf-validator.zip")

  depends_on = [
    aws_s3_object.lambda_code,
    aws_iam_role.lambda_role,
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]
}