
resource "aws_s3_bucket" "images" {
  bucket = "whatthe-images-2"
  tags = {
    Name = "whatthe-images-2"
  }
}

resource "aws_s3_bucket_policy" "images" {
  bucket = aws_s3_bucket.images.id
  policy = data.aws_iam_policy_document.images_cloudfront.json
}

data "aws_iam_policy_document" "images_cloudfront" {
  statement {
    principals {
      type = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = ["s3:GetObject"]
    
    resources = [format("%s/*", aws_s3_bucket.images.arn)]
    
    condition {
      test = "StringEquals"
      variable = "AWS:SourceArn"
      values = [aws_cloudfront_distribution.cloudfront.arn]
    }

    effect = "Allow"
  }
}


resource "aws_s3_bucket" "scaled_images" {
  bucket = "scaled-images2"
  tags = {
    Name = "scaled-images2"
  }
}

resource "aws_s3_bucket_policy" "scaled_images" {
  bucket = aws_s3_bucket.scaled_images.id
  policy = data.aws_iam_policy_document.scaled_images_cloudfront.json
}


data "aws_iam_policy_document" "scaled_images_cloudfront" {
  statement {
    principals {
      type = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = ["s3:GetObject"]
    
    resources = [format("%s/*", aws_s3_bucket.scaled_images.arn)]
    
    condition {
      test = "StringEquals"
      variable = "AWS:SourceArn"
      values = [aws_cloudfront_distribution.cloudfront.arn]
    }

    effect = "Allow"
  }
}
# resource "aws_s3_bucket_acl" "scaled_images" {
#   bucket = aws_s3_bucket.scaled_images.id
#   acl    = "private"
# }