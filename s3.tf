
resource "aws_s3_bucket" "images" {
  bucket = "inventory-raw-images"
  tags = {
    Name = "inventory-raw-images"
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
    actions = ["s3:GetObject", "s3:ListBucket"]
    
    resources = [format("%s/*", aws_s3_bucket.images.arn), aws_s3_bucket.images.arn]
    
    condition {
      test = "StringEquals"
      variable = "AWS:SourceArn"
      values = [aws_cloudfront_distribution.cloudfront.arn, aws_cloudfront_distribution.cloudfront_staging.arn]
    }

    effect = "Allow"
  }
}


resource "aws_s3_bucket" "scaled_images" {
  bucket = "inventory-scaled-images"
  tags = {
    Name = "inventory-scaled-images"
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
    actions = ["s3:GetObject", "s3:ListBucket"]
    
    resources = [format("%s/*", aws_s3_bucket.scaled_images.arn), aws_s3_bucket.scaled_images.arn]
    
    condition {
      test = "StringEquals"
      variable = "AWS:SourceArn"
      values = [aws_cloudfront_distribution.cloudfront.arn, aws_cloudfront_distribution.cloudfront_staging.arn]
    }

    effect = "Allow"
  }
}

resource "aws_s3_bucket_cors_configuration" "images_cors" {
  bucket = aws_s3_bucket.images.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["http://localhost:5173"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# resource "aws_s3_bucket_acl" "scaled_images" {
#   bucket = aws_s3_bucket.scaled_images.id
#   acl    = "private"
# }