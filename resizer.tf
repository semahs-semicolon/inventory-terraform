
data "aws_iam_policy_document" "resizer_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }


    actions = ["sts:AssumeRole"]
  }
}
data "aws_iam_policy_document" "resizer_perm" {
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
  assume_role_policy = data.aws_iam_policy_document.resizer_assume.json

  inline_policy {
    policy = data.aws_iam_policy_document.resizer_perm.json
  }
}


resource "aws_lambda_permission" "resizer_allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resizer.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.images.arn
}



resource "aws_lambda_function" "resizer" {
  function_name = "image_resizer"
  role = aws_iam_role.resizer.arn

  filename = "empty.zip"
  handler = "aa"
  runtime = "nodejs18.x"
}

resource "aws_s3_bucket_notification" "resize_notif" {
    bucket = aws_s3_bucket.images.id

    lambda_function {
        lambda_function_arn = aws_lambda_function.resizer.arn
        events              = ["s3:ObjectCreated:*"]
    }

    depends_on = [aws_lambda_permission.resizer_allow_bucket]
}