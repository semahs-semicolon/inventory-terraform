
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
        "${aws_s3_bucket.images.arn}/*",
        "${aws_s3_bucket.scaled_images.arn}/*"
    ]

    actions = ["s3:PutObject", "s3:GetObject"]
  }
}


resource "aws_iam_role" "resizer" {
  name               = "resizer"
  assume_role_policy = data.aws_iam_policy_document.resizer_assume.json

  inline_policy {
    name = "resizer_perms"
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

  filename = data.archive_file.resizer_code.output_path
  source_code_hash = data.archive_file.resizer_code.output_md5
  handler = "index.handler"
  runtime = "nodejs18.x"

  environment {
    variables = {
      "TARGET_BUCKET": aws_s3_bucket.scaled_images.id
    }
  }
}

resource "aws_s3_bucket_notification" "resize_notif" {
    bucket = aws_s3_bucket.images.id

    lambda_function {
        lambda_function_arn = aws_lambda_function.resizer.arn
        events              = ["s3:ObjectCreated:*"]
    }

    depends_on = [aws_lambda_permission.resizer_allow_bucket]
}


data "archive_file" "resizer_code" {
  type        = "zip"
  source_dir  = "${path.module}/resizer/"
  output_path = "${path.module}/resizer.zip"
}
// auto resizer. Resizing config?