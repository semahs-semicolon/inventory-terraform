# this service categorizes item based on... name. solely name. This is separated from api server because this is long running async job.


data "aws_bedrock_foundation_model" "llama8B" {
  provider = aws.oregon
  model_id = "meta.llama3-8b-instruct-v1:0"
}

data "aws_bedrock_foundation_model" "llama70B" {
  provider = aws.oregon
  model_id = "meta.llama3-70b-instruct-v1:0"
}


data "aws_iam_policy_document" "aicategorizer" {
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
        data.aws_bedrock_foundation_model.llama8B.model_arn,
        data.aws_bedrock_foundation_model.llama70B.model_arn
    ]

    actions = ["bedrock:InvokeModel"]
  }
}


resource "aws_iam_role" "aicategorizer" {
  name               = "aicategorizer"
  assume_role_policy = data.aws_iam_policy_document.aicategorizer.json
}


// TODO
resource "aws_lambda_function" "aicategorizer" {
  function_name = "aicategorizer"
  role = aws_iam_role.aicategorizer.arn

  image_uri = "public.ecr.aws/docker/library/hello-world:nanoserver"
  handler = "asdf"
  runtime = "nodejs18.x"

  publish = true
}