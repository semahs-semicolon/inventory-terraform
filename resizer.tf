
data "aws_iam_policy_document" "resizer" {
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
        aws_s3_bucket.images.arn,
        aws_s3_bucket.scaled_images.arn
    ]

    actions = ["s3:PutObject", "s3:GetObject"]
  }
}


resource "aws_iam_role" "resizer" {
  name               = "resizer"
  assume_role_policy = data.aws_iam_policy_document.resizer.json
}



resource "aws_lambda_function" "resizer" {
  function_name = "image_resizer"
  role = aws_iam_role.resizer.arn

  image_uri = "public.ecr.aws/docker/library/hello-world:nanoserver"
  handler = "aa"
  runtime = "nodejs18.x"
}