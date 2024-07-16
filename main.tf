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


resource "aws_s3_bucket" "inventory_deployment" {
  bucket = "inventory_deployment"

  tags = {
    Name = "inventory_deployment"
  }
}

resource "aws_s3_bucket_acl" "inventory_deployment" {
  bucket = aws_s3_bucket.inventory_deployment.id
  acl    = "private"
}

resource "aws_s3_bucket" "images" {
  bucket = "images"

  tags = {
    Name = "images"
  }
}
resource "aws_s3_bucket_acl" "images" {
  bucket = aws_s3_bucket.images.id
  acl    = "private"
}

resource "aws_s3_bucket" "scaled_images" {
  bucket = "scaled_images"
  tags = {
    Name = "scaled_images"
  }
}

resource "aws_s3_bucket_acl" "scaled_images" {
  bucket = aws_s3_bucket.scaled_images.id
  acl    = "private"
}



resource "aws_instance" "database" {
    ami = "ami-09cb0f54fe24c54a6"
    instance_type = "t2.micro"

    user_data = <<-EOL
        #!/bin/bash -xe
        apt update
        apt install postgresql --yes
        EOL
    // will take care of it manually
  
    tags = {
        Name = "Database"
    }
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
}


resource "aws_iam_role" "apiserver" {
  name               = "apiserver"
  assume_role_policy = data.aws_iam_policy_document.apiserver.json
}




resource "aws_lambda_function" "apiserver" {
  function_name = "apiserver"
  role = aws_iam_role.apiserver.arn

  image_uri = "asdlkasljd"
  handler = "index.test"
  runtime = "nodejs18.x"
#   provisioner "asd" {
    
#   }
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


locals {
  inventory_origin_id = "inventory"
  api_origin_id = "backend"
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

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cloudfront"
  default_root_object = "index.html"

#   logging_config {
#     include_cookies = false
#     bucket          = "mylogs.s3.amazonaws.com"
#     prefix          = "myprefix"
#   }

  aliases = ["inventory.seda.club", "inventory.seda.club"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
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

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}