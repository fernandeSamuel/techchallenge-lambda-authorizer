provider "aws" {
  region = "us-east-2" # Ajuste para a região correta
}

resource "aws_api_gateway_rest_api" "example" {
  name        = "API Gateway Test"
  description = "API Gateway created from OpenAPI spec"
}

resource "aws_api_gateway_resource" "cpf_auth" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "CPFAuth"
}

resource "aws_api_gateway_method" "post_method" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.cpf_auth.id
  http_method   = "POST"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.lambda_authorizer.id
}

resource "aws_api_gateway_authorizer" "lambda_authorizer" {
  name                   = "lambdaAuthorizer"
  rest_api_id            = aws_api_gateway_rest_api.example.id
  type                   = "REQUEST"
  authorizer_uri         = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:148761639942:function:CPFAuth/invocations"
  identity_source        = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds = 0
}

resource "aws_api_gateway_integration" "post_integration" {
  rest_api_id             = aws_api_gateway_rest_api.example.id
  resource_id             = aws_api_gateway_resource.cpf_auth.id
  http_method             = aws_api_gateway_method.post_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-2:148761639942:function:CPFAuth/invocations"
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  stage_name  = "default"

  depends_on = [aws_api_gateway_integration.post_integration]
}


# S3 Bucket para armazenar o código Lambda
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "lambda-code-bucket-cpf-validator-${random_string.suffix.result}"
  acl    = "private"

  tags = {
    Name = "LambdaCodeBucket"
  }

}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

# Role para a Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"
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

# Attach AWS Managed Policy for Lambda Execution
resource "aws_iam_role_policy_attachment" "lambda_execution_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Recurso Lambda
resource "aws_lambda_function" "cpf_validator" {
  function_name = "cpf-validator-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"

  # O código será enviado do S3
  s3_bucket        = aws_s3_bucket.lambda_bucket.bucket
  s3_key           = "cpf-validator.zip"
  source_code_hash = filebase64sha256("lambda/cpf-validator.zip") # Local da função compactada

  tags = {
    Name = "CPFValidatorLambda"
  }
  depends_on = [ aws_api_gateway_rest_api.example,aws_iam_role.lambda_role, aws_s3_bucket.lambda_bucket, aws_iam_role_policy_attachment.lambda_execution_policy ]
}
