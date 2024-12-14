
resource "aws_api_gateway_rest_api" "example" {
  name        = "API Gateway Test"
  description = "API Gateway created from OpenAPI spec"
}

resource "aws_api_gateway_resource" "cpf_auth" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "CPFAuth"

  depends_on = [aws_api_gateway_rest_api.example]
}

resource "aws_api_gateway_authorizer" "lambda_authorizer" {
  name                   = "lambdaAuthorizer"
  rest_api_id            = aws_api_gateway_rest_api.example.id
  type                   = "REQUEST"
  authorizer_uri         = aws_lambda_function.cpf_validator.invoke_arn
  identity_source        = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds = 0

  depends_on = [aws_lambda_function.cpf_validator]
}

resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.cpf_auth.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id

  depends_on = [aws_api_gateway_authorizer.lambda_authorizer]
}

resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.example.id
  resource_id             = aws_api_gateway_resource.cpf_auth.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.cpf_validator.invoke_arn

  depends_on = [aws_api_gateway_method.post_method]
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id

  depends_on = [aws_api_gateway_integration.post_integration]
}

resource "aws_api_gateway_stage" "example_stage" {
  deployment_id = aws_api_gateway_deployment.example.id
  rest_api_id   = aws_api_gateway_rest_api.example.id
  stage_name    = "dev" 
  description   = "Development stage for the API Gateway"

  variables = {
    example_variable = "example_value"
  }

  depends_on = [aws_api_gateway_deployment.example]
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "lambda-code-bucket-cpf-validator-${random_string.suffix.result}"

  tags = {
    Name = "LambdaCodeBucket"
  }
}

resource "aws_s3_object" "lambda_code" {
  bucket = aws_s3_bucket.lambda_bucket.id
  key    = "cpf-validator.zip"
  source = "cpf-validator.zip"
}

resource "aws_s3_bucket_policy" "lambda_bucket_policy" {
  bucket = aws_s3_bucket.lambda_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowWriteForLambda",
        Effect    = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/lambda_execution_role_1"
        },
        Action    = "s3:PutObject",
        Resource  = "${aws_s3_bucket.lambda_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role_1"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_execution_policy" {
  name        = "lambda_execution_policy"
  description = "Policy for Lambda basic execution"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_execution_policy.arn

  depends_on = [aws_iam_role.lambda_role, aws_iam_policy.lambda_execution_policy]
}

resource "aws_lambda_function" "cpf_validator" {
  function_name = "cpf-validator-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  s3_bucket     = aws_s3_bucket.lambda_bucket.bucket
  s3_key        = aws_s3_object.lambda_code.key
  source_code_hash = filebase64sha256("cpf-validator.zip")

  depends_on = [
    aws_s3_bucket.lambda_bucket,
    aws_s3_object.lambda_code,
    aws_iam_role.lambda_role,
    aws_iam_role_policy_attachment.lambda_execution_policy_attachment
  ]
}
