

resource "aws_apigatewayv2_api" "inventory_api" {
  name = "inventory-api"
  protocol_type = "HTTP" 
}



resource "aws_apigatewayv2_integration" "api_server" {
  api_id           = aws_apigatewayv2_api.inventory_api.id
  integration_type = "AWS_PROXY"

  integration_method = "POST"
  integration_uri    = aws_lambda_alias.production.invoke_arn

  request_parameters = {
    "overwrite:path": "$request.path.proxy"
  }
}

resource "aws_apigatewayv2_route" "api_server" {
  api_id    = aws_apigatewayv2_api.inventory_api.id
  route_key = "ANY /{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.api_server.id}"
}


resource "aws_apigatewayv2_integration" "embedding_generator" {
  api_id           = aws_apigatewayv2_api.inventory_api.id
  integration_type = "AWS_PROXY"

  integration_method = "POST"
  integration_uri    = aws_lambda_function.embedding_generator.invoke_arn

  request_parameters = {
    "overwrite:path": "$request.path.proxy"
  }
}

resource "aws_apigatewayv2_route" "embedding_generator" {
  api_id    = aws_apigatewayv2_api.inventory_api.id
  route_key = "ANY /embedding/{proxy+}"

  target = "integrations/${aws_apigatewayv2_integration.embedding_generator.id}"
}




resource "aws_apigatewayv2_stage" "production" {
  api_id = aws_apigatewayv2_api.inventory_api.id
  name = "production"
}

resource "aws_apigatewayv2_stage" "staging" {
  api_id = aws_apigatewayv2_api.inventory_api.id
  name = "staging"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.inventory_api.id
  name = "$default"
}