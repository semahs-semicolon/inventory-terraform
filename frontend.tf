

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


data "aws_iam_policy_document" "inventory_front_deploy_github_actions" {
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
      values = ["repo:sema-semicolon/inventory-front:environment:production"]
    }


    actions = ["sts:AssumeRoleWithWebIdentity"]
  }

  statement {
    effect = "Allow"

    resources = [
        aws_s3_bucket.inventory_deployment.arn,
        format("%s/*", aws_s3_bucket.inventory_deployment.arn),
    ]

    actions = [
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:PutObject"
    ]
  }
}


resource "aws_iam_role" "inventory_front_deploy_github_actions" {
  name               = "inventory_front_deploy_github_actions"
  assume_role_policy = data.aws_iam_policy_document.inventory_front_deploy_github_actions.json
}