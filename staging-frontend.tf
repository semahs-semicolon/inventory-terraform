

resource "aws_s3_bucket" "inventory_deployment_staging" {
  bucket = "semicolon-inventory-deployment-staging"

  tags = {
    Name = "semicolon-inventory-deployment-staging"
  }
}

data "aws_iam_policy_document" "inventory_deployment_staging_cloudfront" {
  statement {
    principals {
      type = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = ["s3:GetObject", "s3:ListBucket"]
    
    resources = [format("%s/*", aws_s3_bucket.inventory_deployment_staging.arn), aws_s3_bucket.inventory_deployment_staging.arn]
    
    condition {
      test = "StringEquals"
      variable = "AWS:SourceArn"
      values = [aws_cloudfront_distribution.cloudfront_staging.arn]
    }

    effect = "Allow"
  }
}

resource "aws_s3_bucket_policy" "inventory_deployment_staging_cloudfront" {
  bucket = aws_s3_bucket.inventory_deployment_staging.id
  policy = data.aws_iam_policy_document.inventory_deployment_staging_cloudfront.json
}

# resource "aws_s3_bucket_acl" "inventory_deployment" {
#   bucket = aws_s3_bucket.inventory_deployment.id
#   acl    = "private"
# }


data "aws_iam_policy_document" "inventory_front_staging_deploy_github_actions_assume" {
  statement {
    effect = "Allow"

    principals {
      type = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
        test = "StringEquals"
        variable = "token.actions.githubusercontent.com:aud"

        values = ["sts.amazonaws.com"] 
    }
    condition {
      test = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = ["repo:semahs-semicolon/inventory-front:environment:staging"]
    }


    actions = ["sts:AssumeRoleWithWebIdentity"]
  }
}

data "aws_iam_policy_document" "inventory_front_staging_deploy_github_actions_perm" {
  
  statement {
    effect = "Allow"

    resources = [
        aws_s3_bucket.inventory_deployment_staging.arn,
        format("%s/*", aws_s3_bucket.inventory_deployment_staging.arn),
    ]

    actions = [
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:HeadObject",
        "s3:ListBucket",
        "s3:PutObject"
    ]
  }
}

resource "aws_iam_role" "inventory_front_staging_deploy_github_actions" {
  name               = "inventory_front_staging_github_actions"
  assume_role_policy = data.aws_iam_policy_document.inventory_front_staging_deploy_github_actions_assume.json

  inline_policy {
    name = "allow_deployment_to_s3"
    policy = data.aws_iam_policy_document.inventory_front_staging_deploy_github_actions_perm.json
  }
}