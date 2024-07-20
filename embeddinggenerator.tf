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

  inline_policy {
    policy = data.aws_iam_policy_document.embedding_generator_perm.json
  }
}


// TODO
resource "aws_lambda_function" "embedding_generator" {
  function_name = "embedding_generator"
  role = aws_iam_role.embedding_generator.arn

  
  filename = "empty.zip"
  handler = "index.js"
  runtime = "nodejs18.x"

  publish = true
}

resource "aws_lambda_function_url" "embedding_generator" {
  function_name = aws_lambda_function.embedding_generator.function_name
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
