# this service categorizes item based on... name. solely name. This is separated from api server because this is long running async job.


data "aws_bedrock_foundation_model" "claude_sonnet" {
  provider = aws.oregon
  model_id = "anthropic.claude-3-sonnet-20240229-v1:0"
}


data "aws_iam_policy_document" "aicategorizer_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }


    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "aicategorizer_perm" {
  statement {
    effect = "Allow"

    resources = [
        data.aws_bedrock_foundation_model.claude_sonnet.model_arn
    ]

    actions = ["bedrock:InvokeModel"]
  }


  statement {
    effect = "Allow"

    resources = [
        aws_ssm_parameter.database_password.arn
    ]

    actions = ["ssm:GetParameter", "kms:Decrypt"]
  }
}


resource "aws_iam_role" "aicategorizer" {
  name               = "aicategorizer"
  assume_role_policy = data.aws_iam_policy_document.aicategorizer_assume.json

  # managed_policy_arns = [data.aws_iam_policy.lambda_vpc.arn]

  managed_policy_arns = [data.aws_iam_policy.lambda_default_execution.arn]


  inline_policy {
    name = "aicategorizer_perms"
    policy = data.aws_iam_policy_document.aicategorizer_perm.json
  }
}


// TODO
resource "aws_lambda_function" "aicategorizer" {
  function_name = "aicategorizer"
  role = aws_iam_role.aicategorizer.arn

  
  filename = data.archive_file.categorizer_code.output_path
  source_code_hash = data.archive_file.categorizer_code.output_md5
  handler = "index.handler"
  runtime = "nodejs18.x"


  environment {
    variables = {
      "PGHOST": aws_instance.database.public_ip,
      "PGPORT": "5432",
      "PGUSER": "inventory_system",
      "PGDATABASE": "inventory",
      "DATABASE_PASSWORD_PARAM_NAME": aws_ssm_parameter.database_password.id,
      "MODEL_ID": data.aws_bedrock_foundation_model.claude_sonnet.model_id
    }
  }

  timeout = 30


  # vpc_config {
  #   security_group_ids = [ aws_default_security_group.default_sg.id ]
  #   subnet_ids = [ for k,v in aws_subnet.public_subnets : v.id ]
  # }
}

data "archive_file" "categorizer_code" {
  type        = "zip"
  source_dir  = "${path.module}/categorizer/"
  output_path = "${path.module}/categorizer.zip"
}