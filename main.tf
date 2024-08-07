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

  backend "s3" {
    bucket = "semicolon-terraform-state"
    key    = "tfstate"
    region = "ap-northeast-2"
    profile = "semicolon-inventory"

    dynamodb_table = "semicolon-terraform-dynamodbbackend"
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-northeast-2"
  profile = "semicolon-inventory"
}

provider "aws" {
  alias = "oregon"
  region  = "us-west-2"
  profile = "semicolon-inventory"
}
provider "aws" {
  alias = "virginia"
  region  = "us-east-1"
  profile = "semicolon-inventory"
}

provider "cloudflare" {
}



locals {
  inventory_origin_id = "inventory"
  api_origin_id = "backend"
  image_origin_id = "image"
  scaled_image_origin_id = "scaledimage" 

  domain_name = "inventory.seda.club"
  staging_domain_name = "staging.inventory.seda.club"
}

resource "aws_s3_bucket" "cf_logging" {
    bucket = "inventory-cloudfront-logging"
    tags ={
        Name = "inventory-cloudfront-logging"
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

resource "aws_s3_bucket_lifecycle_configuration" "cf_logging" {
  bucket = aws_s3_bucket.cf_logging.id

  rule {
    id = "DeleteOldLogs"

    filter {}

    expiration {
      days = 7
    }

    status = "Enabled"
  }
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
  signing_behavior                  = "never"
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
resource "aws_acm_certificate" "cert_staging" {
  provider = aws.virginia
  domain_name       = local.staging_domain_name
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

resource "cloudflare_record" "cert_validation_staging" {
  for_each = {
    for dvo in aws_acm_certificate.cert_staging.domain_validation_options : dvo.domain_name => {
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
resource "aws_acm_certificate_validation" "cert_staging_valid" {
  provider = aws.virginia
  certificate_arn = aws_acm_certificate.cert_staging.arn
}

resource "aws_cloudfront_cache_policy" "cacheoptimized_cors" {
  name        = "cache-optimized-with-cors"
  comment     = "test comment"
  default_ttl = 86400
  max_ttl     = 31536000
  min_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    query_strings_config {
      query_string_behavior = "none"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Origin"]
      }
    }
    cookies_config {
      cookie_behavior = "none"
    }
  }
}

data "aws_cloudfront_cache_policy" "cachedisabled" {
  name = "Managed-CachingDisabled"
}
data "aws_cloudfront_cache_policy" "cacheoptimized" {
  name = "Managed-CachingOptimized"
}
data "aws_cloudfront_origin_request_policy" "allexcepthost" {
  name = "Managed-AllViewerExceptHostHeader"
}
data "aws_cloudfront_origin_request_policy" "cors" {
  name = "Managed-CORS-CustomOrigin"
}


resource "aws_cloudfront_function" "removeapifunc" {
  name = "removeapi"
  runtime = "cloudfront-js-2.0"
  publish = true
  code = <<-EOL
  function handler(event) {
    var request = event.request;
    request.uri = request.uri.replace(/^\/[^/]*\//, "/");
    return request;
  }
  EOL
}
resource "aws_cloudfront_function" "removeapifunc_addstaging" {
  name = "removeapi_staging"
  runtime = "cloudfront-js-2.0"
  publish = true
  code = <<-EOL
  function handler(event) {
    var request = event.request;
    request.uri = request.uri.replace(/^\/[^/]*\//, "/staging/");
    return request;
  }
  EOL
}

resource "aws_cloudfront_function" "spa" {
  name = "spa"
  runtime = "cloudfront-js-2.0"
  publish = true
  code = <<-EOL
  function handler(event) {
    var request = event.request;
    if (!request.uri.includes(".")) {
      request.uri = "/200.html"
    }
    return request;
  }
  EOL
}


resource "aws_cloudfront_distribution" "cloudfront" {
  origin {
    domain_name              = aws_s3_bucket.inventory_deployment.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    origin_id                = local.inventory_origin_id
  }

  origin {
    domain_name = replace(aws_apigatewayv2_api.inventory_api.api_endpoint, "/(^https://)|(/$)/","")
    origin_id = local.api_origin_id

    # origin_access_control_id = aws_cloudfront_origin_access_control.api.id

    custom_origin_config {
      origin_ssl_protocols = ["TLSv1.2", "TLSv1.1", "TLSv1", "SSLv3"]
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
    }
  }

  origin {
    domain_name = aws_s3_bucket.images.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    origin_id = local.image_origin_id
  }
  origin {
    domain_name = aws_s3_bucket.scaled_images.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    origin_id = local.scaled_image_origin_id
  }


  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cloudfront"
  default_root_object = "200.html"

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

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400


    function_association {
      function_arn = aws_cloudfront_function.spa.arn
      event_type = "viewer-request"
    }
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


    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id  = data.aws_cloudfront_cache_policy.cachedisabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.allexcepthost.id

    function_association {
      function_arn = aws_cloudfront_function.removeapifunc.arn
      event_type = "viewer-request"
    }
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

    viewer_protocol_policy = "redirect-to-https"
    min_ttl = 0
    max_ttl = 86400
    default_ttl = 3600

    function_association {
      function_arn = aws_cloudfront_function.removeapifunc.arn
      event_type = "viewer-request"
    }
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

    viewer_protocol_policy = "redirect-to-https"
    min_ttl = 0
    max_ttl = 86400
    default_ttl = 3600


    function_association {
      function_arn = aws_cloudfront_function.removeapifunc.arn
      event_type = "viewer-request"
    }
  }


  tags = {
    Environment = "production"
  }

  viewer_certificate {
    # cloudfront_default_certificate = true
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method = "sni-only"
  }

  # custom_error_response {
  #   error_code = 404
  #   response_code = 200
  #   response_page_path = "/200.html"
  # }

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


resource "aws_cloudfront_distribution" "cloudfront_staging" {
  origin {
    domain_name              = aws_s3_bucket.inventory_deployment_staging.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    origin_id                = local.inventory_origin_id
  }

  origin {
    domain_name = replace(aws_apigatewayv2_api.inventory_api.api_endpoint, "/(^https://)|(/$)/","")
    origin_id = local.api_origin_id

    # origin_access_control_id = aws_cloudfront_origin_access_control.api.id

    custom_origin_config {
      origin_ssl_protocols = ["TLSv1.2", "TLSv1.1", "TLSv1", "SSLv3"]
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
    }
  }

  origin {
    domain_name = aws_s3_bucket.images.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    origin_id = local.image_origin_id
  }
  origin {
    domain_name = aws_s3_bucket.scaled_images.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
    origin_id = local.scaled_image_origin_id
  }


  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cloudfront"
  default_root_object = "200.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cf_logging.bucket_domain_name
    prefix          = "accesslog.staging"
  }

  aliases = [local.staging_domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.inventory_origin_id

    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id  = data.aws_cloudfront_cache_policy.cachedisabled.id

    function_association {
      function_arn = aws_cloudfront_function.spa.arn
      event_type = "viewer-request"
    }
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


    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id  = data.aws_cloudfront_cache_policy.cachedisabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.allexcepthost.id

    function_association {
      function_arn = aws_cloudfront_function.removeapifunc_addstaging.arn
      event_type = "viewer-request"
    }
  }


  ordered_cache_behavior {
    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.image_origin_id

    path_pattern = "/image/**"

    viewer_protocol_policy = "redirect-to-https"

    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.cors.id
    cache_policy_id = aws_cloudfront_cache_policy.cacheoptimized_cors.id

    function_association {
      function_arn = aws_cloudfront_function.removeapifunc.arn
      event_type = "viewer-request"
    }

    
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

    viewer_protocol_policy = "redirect-to-https"
    min_ttl = 0
    max_ttl = 86400
    default_ttl = 3600


    function_association {
      function_arn = aws_cloudfront_function.removeapifunc.arn
      event_type = "viewer-request"
    }
  }


  tags = {
    Environment = "staging"
  }

  viewer_certificate {
    # cloudfront_default_certificate = true
    acm_certificate_arn = aws_acm_certificate.cert_staging.arn
    ssl_support_method = "sni-only"
  }

  # custom_error_response {
  #   error_code = 404
  #   response_code = 200
  #   response_page_path = "/200.html"
  # }

  depends_on = [ aws_s3_bucket_ownership_controls.cf_logging, aws_s3_bucket_acl.cf_logging, aws_acm_certificate_validation.cert_staging_valid ]
}


resource "cloudflare_record" "connect_staging" {
  zone_id = data.cloudflare_zone.this.zone_id
  type = "CNAME"
  name = local.staging_domain_name
  value = aws_cloudfront_distribution.cloudfront_staging.domain_name
  ttl = 60
  proxied = false

  allow_overwrite = true
}