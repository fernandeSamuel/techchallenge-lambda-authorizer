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

# Política para execução da Lambda, logs e VPC
resource "aws_iam_policy" "lambda_execution_policy" {
  name        = "lambda_execution_policy_http_api"
  description = "Policy for Lambda execution with VPC and logs permissions"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Permissões para logs
      {
        Effect   = "Allow",
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      # Permissões para criar, descrever e deletar interfaces de rede na VPC
      {
        Effect   = "Allow",
        Action   = [
          "ec2:*"
        ],
        Resource = "*"
      },
      # Permissão adicional para acessar S3 (se necessário para o código Lambda)
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject"
        ],
        Resource = "arn:aws:s3:::lambda-code-bucket-cpf-validator-*/*"
      }
    ]
  })
}

# Anexar política à Role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_execution_policy.arn
}
