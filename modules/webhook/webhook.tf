resource "aws_lambda_function" "webhook" {
  s3_bucket         = var.lambda_s3_bucket != null ? var.lambda_s3_bucket : null
  s3_key            = var.webhook_lambda_s3_key != null ? var.webhook_lambda_s3_key : null
  s3_object_version = var.webhook_lambda_s3_object_version != null ? var.webhook_lambda_s3_object_version : null
  filename          = var.lambda_s3_bucket == null ? local.lambda_zip : null
  source_code_hash  = var.lambda_s3_bucket == null ? filebase64sha256(local.lambda_zip) : null
  function_name     = "${var.prefix}-webhook"
  role              = aws_iam_role.webhook_lambda.arn
  handler           = "index.githubWebhook"
  runtime           = var.lambda_runtime
  timeout           = var.lambda_timeout
  architectures     = [var.lambda_architecture]

  environment {
    variables = {
      ENABLE_WORKFLOW_JOB_LABELS_CHECK = var.enable_workflow_job_labels_check
      WORKFLOW_JOB_LABELS_CHECK_ALL    = var.workflow_job_labels_check_all
      ENVIRONMENT                      = var.prefix
      LOG_LEVEL                        = var.log_level
      LOG_TYPE                         = var.log_type
      REPOSITORY_WHITE_LIST            = jsonencode(var.repository_white_list)
      RUNNER_LABELS                    = jsonencode(split(",", var.runner_labels))
      SQS_URL_WEBHOOK                  = var.sqs_build_queue.id
      SQS_IS_FIFO                      = var.sqs_build_queue_fifo
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "webhook" {
  name              = "/aws/lambda/${aws_lambda_function.webhook.function_name}"
  retention_in_days = var.logging_retention_in_days
  kms_key_id        = var.logging_kms_key_id
  tags              = var.tags
}

resource "aws_lambda_permission" "webhook" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webhook.execution_arn}/*/*/${local.webhook_endpoint}"
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "webhook_lambda" {
  name                 = "${var.prefix}-action-webhook-lambda-role"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role_policy.json
  path                 = local.role_path
  permissions_boundary = var.role_permissions_boundary
  tags                 = var.tags
}

resource "aws_iam_role_policy" "webhook_logging" {
  name = "${var.prefix}-lambda-logging-policy"
  role = aws_iam_role.webhook_lambda.name
  policy = templatefile("${path.module}/policies/lambda-cloudwatch.json", {
    log_group_arn = aws_cloudwatch_log_group.webhook.arn
  })
}

resource "aws_iam_role_policy" "webhook_sqs" {
  name = "${var.prefix}-lambda-webhook-publish-sqs-policy"
  role = aws_iam_role.webhook_lambda.name

  policy = templatefile("${path.module}/policies/lambda-publish-sqs-policy.json", {
    sqs_resource_arn = var.sqs_build_queue.arn
  })
}

resource "aws_iam_role_policy" "webhook_ssm" {
  name = "${var.prefix}-lambda-webhook-publish-ssm-policy"
  role = aws_iam_role.webhook_lambda.name

  policy = templatefile("${path.module}/policies/lambda-ssm.json", {
    github_app_webhook_secret_arn = var.github_app_webhook_secret_arn,
    kms_key_arn                   = var.kms_key_arn != null ? var.kms_key_arn : ""
  })
}
