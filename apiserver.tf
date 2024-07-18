
data "aws_bedrock_foundation_model" "llama8B" {
  provider = aws.oregon
  model_id = "meta.llama3-8b-instruct-v1:0"
}

data "aws_bedrock_foundation_model" "llama70B" {
  provider = aws.oregon
  model_id = "meta.llama3-70b-instruct-v1:0"
}


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
        data.aws_bedrock_foundation_model.llama8B.model_arn,
        data.aws_bedrock_foundation_model.llama70B.model_arn
    ]

    actions = ["bedrock:InvokeModel"]

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
