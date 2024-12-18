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

# Lambda Authorizer para validar CPF
resource "aws_apigatewayv2_authorizer" "lambda_authorizer" {
  api_id           = aws_apigatewayv2_api.http_api.id
  name             = "cpf-authorizer"
  authorizer_type  = "REQUEST"
  authorizer_uri   = aws_lambda_function.cpf_validator.invoke_arn
  identity_sources = ["$request.header.Authorization"]

  authorizer_payload_format_version = "2.0"

  depends_on = [aws_lambda_function.cpf_validator]
}

# Permissão para o API Gateway invocar a Lambda Authorizer
resource "aws_lambda_permission" "http_api_gateway_authorizer_permission" {
  statement_id  = "AllowHttpApiGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cpf_validator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*"
}

# Integração do HTTP API Gateway com a Lambda principal
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                  = aws_apigatewayv2_api.http_api.id
  integration_type        = "AWS_PROXY"
  integration_uri         = aws_lambda_function.cpf_validator.invoke_arn
  payload_format_version  = "2.0"

  depends_on = [aws_lambda_function.cpf_validator]
}

# Configuração da rota POST /auth com o Authorizer associado
resource "aws_apigatewayv2_route" "cpf_auth_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /auth"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.lambda_authorizer.id

  depends_on = [aws_apigatewayv2_integration.lambda_integration, aws_apigatewayv2_authorizer.lambda_authorizer]
}

# Deployment do HTTP API Gateway
resource "aws_apigatewayv2_stage" "dev_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "dev"
  auto_deploy = true

  depends_on = [aws_apigatewayv2_route.cpf_auth_route]
}

# Permissão para o API Gateway invocar a Lambda principal
resource "aws_lambda_permission" "http_api_gateway_invoke_lambda" {
  statement_id  = "AllowHttpApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cpf_validator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*"
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
      }, 
      {
        Effect   = "Allow",
        Action   = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ],
        Resource = "*"
      }
    ]
  })
}

# Anexar política à Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
}

# Lambda Function para CPF Validator
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

  vpc_config {
    subnet_ids         = data.terraform_remote_state.network.outputs.public_subnet_ids
    security_group_ids = [data.terraform_remote_state.network.outputs.aws_security_group_id]
  }
}
