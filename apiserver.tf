

data "aws_iam_policy_document" "apiserver_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }


    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "apiserver_perm" {

  statement {
    effect = "Allow"

    resources = [
        aws_s3_bucket.images.arn,
        format("%s/*", aws_s3_bucket.images.arn),
    ]

    actions = ["s3:PutObject", "s3:GetObject"]
  }

  statement {
    effect = "Allow"

    resources = [
        aws_lambda_function.aicategorizer.arn
    ]

    actions = ["lambda:InvokeFunctionUrl", "lambda:InvokeFunction"]
  }

  statement {
    effect = "Allow"

    resources = [
        aws_lambda_function.embedding_generator.arn
    ]

    actions = ["lambda:InvokeFunction"]
  }

  statement {
    effect = "Allow"

    resources = [
        aws_ssm_parameter.jwt_privkey.arn,
        aws_ssm_parameter.jwt_pubkey.arn,
        aws_ssm_parameter.database_password.arn
    ]

    actions = ["ssm:GetParameter", "kms:Decrypt"]
  }
}

data "aws_iam_policy" "lambda_default_execution" {
  name = "AWSLambdaBasicExecutionRole"
}
# data "aws_iam_policy" "lambda_vpc" {
#   name = "AWSLambdaVPCAccessExecutionRole"
# }

resource "aws_iam_role" "apiserver" {
  name               = "apiserver"
  assume_role_policy = data.aws_iam_policy_document.apiserver_assume.json

  managed_policy_arns = [data.aws_iam_policy.lambda_default_execution.arn]

  inline_policy {
    name = "apiserver_perms"
    policy = data.aws_iam_policy_document.apiserver_perm.json
  }
}


resource "aws_ssm_parameter" "jwt_pubkey" {
  type = "SecureString"
  name = "jwt_pubkey"
  value = "e"
  overwrite = false
  lifecycle {
    ignore_changes  = ["value", "overwrite"]
  }
}
resource "aws_ssm_parameter" "jwt_privkey" {
  type = "SecureString"
  name = "jwt_privkey"
  value = "e"
  overwrite = false

  lifecycle {
    ignore_changes  = ["value", "overwrite"]
  }
}

// TODO
resource "aws_lambda_function" "apiserver" {
  function_name = "apiserver"
  role = aws_iam_role.apiserver.arn

  
  filename = "empty.zip"
  handler = "io.seda.inventory.InventoryLambdaHandler"
  runtime = "java17"

  publish = true

  environment {
    variables = {
      "CATEGORIZATION_LAMBDA_ARN": aws_lambda_function.aicategorizer.arn,
      "EMBEDDING_LAMBDA_URL": "${ aws_apigatewayv2_stage.production.invoke_url }/embedding",
      "DATABASE_HOSTNAME": aws_instance.database.public_ip,
      "IMAGE_BUCKET": aws_s3_bucket.images.id,
      "JWT_PUBKEY_PARAM_NAME": aws_ssm_parameter.jwt_pubkey.id,
      "JWT_PRIVKEY_PARAM_NAME": aws_ssm_parameter.jwt_privkey.id,
      "DATABASE_PASSWORD_PARAM_NAME": aws_ssm_parameter.database_password.id,
      "JWT_RANDOM": "false"
    }
  }
  # vpc_config {
  #   security_group_ids = [ aws_default_security_group.default_sg.id ]
  #   subnet_ids = [ for k,v in aws_subnet.public_subnets : v.id ]
  # }
  

  memory_size = 512

  snap_start {
    apply_on = "PublishedVersions"
  }
}

resource "aws_lambda_permission" "apiserver_cloudfront" {
  statement_id = "AllowCloudFrontExecuteAPIServer"
  function_name = aws_lambda_function.apiserver.arn
  action = "lambda:InvokeFunction"
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.inventory_api.execution_arn}/**"
  qualifier = aws_lambda_alias.production.name
  # function_url_auth_type = "AWS_IAM"
}

resource "aws_lambda_alias" "production" {
  function_version = aws_lambda_function.apiserver.version
  function_name = aws_lambda_function.apiserver.function_name
  name = "production"
}



data "aws_iam_policy_document" "apiserver_deploy_github_actions_assume" {
  statement {
    effect = "Allow"

    principals {
      type = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
        test = "StringEquals"
        variable = "token.actions.githubusercontent.com:aud"

        values = ["sts.amazonaws.com"] 
    }
    condition {
      test = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = ["repo:semahs-semicolon/inventory-backend:environment:production"]
    }


    actions = ["sts:AssumeRoleWithWebIdentity"]
  }
}

data "aws_iam_policy_document" "apiserver_deploy_github_actions_perm" {
  
  statement {
    effect = "Allow"

    resources = [
        aws_lambda_function.apiserver.arn
    ]

    actions = [
        "lambda:PublishVersion",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateAlias"
    ]
  }
}


resource "aws_iam_role" "apiserver_deploy_github_actions" {
  name               = "apiserver_deploy_github_actions"
  assume_role_policy = data.aws_iam_policy_document.apiserver_deploy_github_actions_assume.json


  inline_policy {
    name = "allow_deployment_to_lambda_apiserver"
    policy = data.aws_iam_policy_document.apiserver_deploy_github_actions_perm.json
  }
}