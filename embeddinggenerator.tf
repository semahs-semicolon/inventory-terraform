// this file is for image embedding generator, for iamge search

data "aws_iam_policy_document" "embedding_generator_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }


    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "embedding_generator_perm" {
  statement {
    effect = "Allow"

    actions = ["s3:GetObject"]

    resources = [ format("%s/*", aws_s3_bucket.images.arn) ]
  }
}

resource "aws_iam_role" "embedding_generator" {
  name               = "embedding_generator"
  assume_role_policy = data.aws_iam_policy_document.embedding_generator_assume.json

  managed_policy_arns = [ data.aws_iam_policy.lambda_default_execution.arn ]

  inline_policy {
    name = "embeddinggen_perms"
    policy = data.aws_iam_policy_document.embedding_generator_perm.json
  }
}


resource "aws_lambda_function" "embedding_generator" {
  function_name = "embedding_generator"
  role = aws_iam_role.embedding_generator.arn

  image_uri = "851725607847.dkr.ecr.ap-northeast-2.amazonaws.com/embeddinggen:v6" 
  package_type = "Image"


  memory_size = 2000
  timeout = 30

  environment {
    variables = {
      "BUCKET": aws_s3_bucket.images.id
    }
  }
}

resource "aws_lambda_permission" "embedding_generator_apigateway" {
  statement_id = "AllowAPIGatewayExecuteAPIServer"
  function_name = aws_lambda_function.embedding_generator.arn
  action = "lambda:InvokeFunction"
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.inventory_api.execution_arn}/**"
}

resource "aws_lambda_permission" "embedding_generator_events" {
    statement_id = "AllowExecutionFromEventBridge"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.embedding_generator.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.keep_embedder_warm.arn
}

resource "aws_cloudwatch_event_rule" "keep_embedder_warm" {
  name = "EmbedderWarmer"
  schedule_expression = "rate(5 minutes)"
}


resource "aws_cloudwatch_event_target" "keep_embeeder_warm_target" {
  rule      = aws_cloudwatch_event_rule.keep_embedder_warm.name
  arn       = aws_lambda_function.embedding_generator.arn
  input = ""
  count = 1
}

resource "aws_ecr_repository" "embedder_repo" {
  name = "embeddingen"
}