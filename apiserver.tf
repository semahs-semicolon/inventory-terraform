

data "aws_iam_policy_document" "apiserver" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }


    actions = ["sts:AssumeRole"]
  }

  statement {
    effect = "Allow"

    resources = [
        aws_s3_bucket.images.arn
    ]

    actions = ["s3:PutObject", "s3:GetObject"]
  }

  statement {
    effect = "Allow"

    resources = [
        aws_lambda_function.aicategorizer.arn
    ]

    actions = ["lambda:InvokeFunctionUrl"]
  }

  statement {
    effect = "Allow"

    resources = [
        module.image_embedding.sagemaker_endpoint.arn
    ]

    actions = ["sagemaker:InvokeEndpoint"]
  }
}


resource "aws_iam_role" "apiserver" {
  name               = "apiserver"
  assume_role_policy = data.aws_iam_policy_document.apiserver.json
}


// TODO
resource "aws_lambda_function" "apiserver" {
  function_name = "apiserver"
  role = aws_iam_role.apiserver.arn

  image_uri = "public.ecr.aws/docker/library/hello-world:nanoserver"
  handler = "io.seda.inventory.InventoryLambdaHandler"
  runtime = "java17"

  publish = true
}

resource "aws_lambda_function_url" "apiserver" {
  function_name = aws_lambda_function.apiserver.function_name
  authorization_type = "AWS_IAM"


  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}
