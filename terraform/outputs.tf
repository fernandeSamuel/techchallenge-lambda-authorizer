# Outputs da Lambda Function
output "lambda_function_arn" {
  description = "ARN da função Lambda CPF Validator para uso em outros recursos ou módulos"
  value       = aws_lambda_function.cpf_validator.arn
}

output "lambda_function_invoke_arn" {
  description = "ARN para invocar a função Lambda CPF Validator"
  value       = aws_lambda_function.cpf_validator.invoke_arn
}

# Outputs do API Gateway
output "api_gateway_rest_api_id" {
  description = "ID do API Gateway, necessário para configurações adicionais"
  value       = aws_api_gateway_rest_api.example.id
}

output "api_gateway_root_resource_id" {
  description = "Root resource ID do API Gateway, necessário para criação de recursos adicionais"
  value       = aws_api_gateway_rest_api.example.root_resource_id
}

output "api_gateway_resource_id_cpf_auth" {
  description = "ID do recurso CPF Auth no API Gateway, usado para associar métodos"
  value       = aws_api_gateway_resource.cpf_auth.id
}

output "api_gateway_authorizer_id" {
  description = "ID do Lambda Authorizer no API Gateway"
  value       = aws_api_gateway_authorizer.lambda_authorizer.id
}

# Outputs do Bucket S3
output "s3_bucket_name" {
  description = "Nome do bucket S3 para armazenamento do código da Lambda"
  value       = aws_s3_bucket.lambda_bucket.bucket
}

# Outputs do IAM Role
output "lambda_role_arn" {
  description = "ARN da IAM Role associada à função Lambda"
  value       = aws_iam_role.lambda_role.arn
}

output "lambda_role_name" {
  description = "Nome da IAM Role associada à função Lambda"
  value       = aws_iam_role.lambda_role.name
}

# Outputs da IAM Policy Customizada
output "lambda_execution_policy_1_arn" {
  description = "ARN da policy customizada para execução da Lambda"
  value       = aws_iam_policy.lambda_execution_policy_1.arn
}
