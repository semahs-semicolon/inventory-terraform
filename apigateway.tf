

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


# resource "aws_apigatewayv2_deployment" "production_deployment" {
#   api_id = aws_apigatewayv2_api.inventory_api.id
  
#   depends_on = [ aws_apigatewayv2_route.api_server ]
# }


resource "aws_apigatewayv2_stage" "production" {
  api_id = aws_apigatewayv2_api.inventory_api.id
  name = "production"

#   deployment_id = aws_apigatewayv2_deployment.production_deployment.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.inventory_api.id
  name = "$default"

#   deployment_id = aws_apigatewayv2_deployment.production_deployment.id
}