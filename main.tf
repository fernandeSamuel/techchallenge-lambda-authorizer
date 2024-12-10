provider "aws" {
  region = "us-east-2" # Ajuste para a região correta
}

# S3 Bucket para armazenar o código Lambda
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = "lambda-code-bucket-${random_string.suffix.result}"
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
}
