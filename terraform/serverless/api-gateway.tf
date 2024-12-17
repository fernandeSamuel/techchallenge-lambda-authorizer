# Criação do HTTP API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "http-api-cpf-validator"
  protocol_type = "HTTP"
  description   = "HTTP API Gateway integrado com Lambda CPF Validator"
}

# Integração do HTTP API Gateway com a Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.cpf_validator.invoke_arn
  payload_format_version = "2.0"

  depends_on = [aws_lambda_function.cpf_validator]
}

# Configuração da rota POST /auth
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
