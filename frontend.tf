

resource "aws_s3_bucket" "inventory_deployment" {
  bucket = "inventory-deployment"

  tags = {
    Name = "inventory-deployment"
  }
}

data "aws_iam_policy_document" "inventory_deployment_cloudfront" {
  statement {
    principals {
      type = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = ["s3:GetObject", "s3:ListBucket"]
    
    resources = [format("%s/*", aws_s3_bucket.inventory_deployment.arn), aws_s3_bucket.inventory_deployment.arn]
    
    condition {
      test = "StringEquals"
      variable = "AWS:SourceArn"
      values = [aws_cloudfront_distribution.cloudfront.arn]
    }

    effect = "Allow"
  }
}

resource "aws_s3_bucket_policy" "inventory_deployment_cloudfront" {
  bucket = aws_s3_bucket.inventory_deployment.id
  policy = data.aws_iam_policy_document.inventory_deployment_cloudfront.json
}

# resource "aws_s3_bucket_acl" "inventory_deployment" {
#   bucket = aws_s3_bucket.inventory_deployment.id
#   acl    = "private"
# }


data "aws_iam_policy_document" "inventory_front_deploy_github_actions_assume" {
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
      values = ["repo:semahs-semicolon/inventory-front:environment:production"]
    }


    actions = ["sts:AssumeRoleWithWebIdentity"]
  }
}

data "aws_iam_policy_document" "inventory_front_deploy_github_actions_perm" {
  
  statement {
    effect = "Allow"

    resources = [
        aws_s3_bucket.inventory_deployment.arn,
        format("%s/*", aws_s3_bucket.inventory_deployment.arn),
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

resource "aws_iam_role" "inventory_front_deploy_github_actions" {
  name               = "inventory_front_deploy_github_actions"
  assume_role_policy = data.aws_iam_policy_document.inventory_front_deploy_github_actions_assume.json

  inline_policy {
    name = "allow_deployment_to_s3"
    policy = data.aws_iam_policy_document.inventory_front_deploy_github_actions_perm.json
  }
}