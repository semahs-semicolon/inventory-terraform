terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.58"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
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
  profile = "semicolon-inventory-test"
}

provider "aws" {
  alias = "oregon"
  region  = "us-west-2"
  profile = "semicolon-inventory-test"
}
provider "aws" {
  alias = "virginia"
  region  = "us-east-1"
  profile = "semicolon-inventory-test"
}

provider "cloudflare" {
}



locals {
  inventory_origin_id = "inventory"
  api_origin_id = "backend"
  image_origin_id = "image"
  scaled_image_origin_id = "scaledimage" 

  domain_name = "inventory-test.seda.club"
}

resource "aws_s3_bucket" "cf_logging" {
    bucket = "cloudfront-logging222"
    tags ={
        Name = "cloudfront-logging222"
    }
}
resource "aws_s3_bucket_ownership_controls" "cf_logging" {
  bucket = aws_s3_bucket.cf_logging.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cf_logging" {
  bucket = aws_s3_bucket.cf_logging.id
  acl    = "private"

  depends_on = [ aws_s3_bucket_ownership_controls.cf_logging ]
}


resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "s3"
  description                       = "s3 Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
resource "aws_cloudfront_origin_access_control" "api" {
  name                              = "lambda"
  description                       = "Lambda Policy"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_acm_certificate" "cert" {
  provider = aws.virginia
  domain_name       = local.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}


data "cloudflare_zone" "this" {
  name = "seda.club"
}

resource "cloudflare_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }


  zone_id = data.cloudflare_zone.this.id
  name = each.value.name
  type = each.value.type
  value = each.value.record
  ttl     = 60
  proxied = false

  allow_overwrite = true
}


resource "aws_acm_certificate_validation" "cert_valid" {
  provider = aws.virginia
  certificate_arn = aws_acm_certificate.cert.arn
}

resource "aws_cloudfront_distribution" "cloudfront" {
  origin {
    domain_name              = aws_s3_bucket.inventory_deployment.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    origin_id                = local.inventory_origin_id
  }

  origin {
    domain_name = replace(aws_lambda_function_url.apiserver.function_url,"/(^https://)|(/$)/","")
    origin_id = local.api_origin_id

    custom_origin_config {
      origin_ssl_protocols = ["TLSv1.2", "TLSv1.1", "TLSv1", "SSLv3"]
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
    }
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

  aliases = [local.domain_name]

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
    cached_methods = ["GET", "HEAD", "OPTIONS"]
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

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

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

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    max_ttl = 86400
    default_ttl = 3600
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    # cloudfront_default_certificate = true
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method = "sni-only"
  }

  depends_on = [ aws_s3_bucket_ownership_controls.cf_logging, aws_s3_bucket_acl.cf_logging, aws_acm_certificate_validation.cert_valid ]
}


resource "cloudflare_record" "connect" {
  zone_id = data.cloudflare_zone.this.zone_id
  type = "CNAME"
  name = local.domain_name
  value = aws_cloudfront_distribution.cloudfront.domain_name
  ttl = 60
  proxied = false

  allow_overwrite = true
}