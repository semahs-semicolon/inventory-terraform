terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.58"
    }
  }

#   backend "s3" {
#     bucket = "terraform-state"
#     key    = "tfstate"
#     region = "ap-northeast-2"
#   }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "semicolon-inventory"
}




locals {
  inventory_origin_id = "inventory"
  api_origin_id = "backend"
  image_origin_id = "image"
  scaled_image_origin_id = "scaledimage" 
}

resource "aws_s3_bucket" "cf_logging" {
    bucket = "cloudfront_logging"
    tags ={
        Name = "cloudfront_logging"
    }
}



resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "example"
  description                       = "Example Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
resource "aws_cloudfront_origin_access_control" "api" {
  name                              = "example"
  description                       = "Example Policy"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}





resource "aws_cloudfront_distribution" "cloudfront" {
  origin {
    domain_name              = aws_s3_bucket.inventory_deployment.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    origin_id                = local.inventory_origin_id
  }

  origin {
    domain_name = aws_lambda_function.apiserver.arn
    origin_access_control_id = aws_cloudfront_origin_access_control.api.id
    origin_id = local.api_origin_id
  }

  origin {
    domain_name = aws_s3_bucket.scaled_images.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    origin_id = local.scaled_image_origin_id
  }
  origin {
    domain_name = aws_s3_bucket.images.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    origin_id = local.image_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cloudfront"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cf_logging.bucket_domain_name
    prefix          = "accesslog"
  }

  aliases = ["inventory.seda.club"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.inventory_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["KR"]
    }
  }

  ordered_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods = []
    target_origin_id = local.api_origin_id

    path_pattern = "/api/**"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    max_ttl = 0
    default_ttl = 0
  }


  ordered_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.image_origin_id

    path_pattern = "/image/**"

    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    max_ttl = 86400
    default_ttl = 3600
  }

  ordered_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.scaled_image_origin_id

    path_pattern = "/scaled/**"

    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    max_ttl = 86400
    default_ttl = 3600
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

