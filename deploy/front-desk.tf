data "archive_file" "kinetic_ws_front_desk" {
  type        = "zip"
  output_path = "${path.module}/../front-desk/lambda/bundled.zip"
  source_dir  = "${path.module}/../front-desk/lambda"
  depends_on  = [null_resource.build_front_desk_lambda]
}

resource "null_resource" "build_front_desk_lambda" {
  triggers = {
    src_sha        = local.lambda_source_sha
    front_desk_sha = local.front_desk_sha
  }

  provisioner "local-exec" {
    command = "cd ${path.module}/../front-desk && ./bin/build"
  }
}

resource "aws_s3_object" "kinetic_ws_fd_asset_files" {
  for_each     = fileset("${path.module}/../front-desk/dist/assets", "*")
  bucket       = aws_s3_bucket.kinetic_ws_assets.id
  key          = "assets/${each.value}"
  source       = "${path.module}/../front-desk/dist/assets/${each.value}"
  source_hash  = local.front_desk_sha
  content_type = lookup(local.mime_types, regex("\\.[^.]+$", each.value), null)
}

resource "aws_s3_object" "kinetic_ws_fd_index" {
  bucket       = aws_s3_bucket.kinetic_ws_assets.id
  key          = "editor/index.html"
  content_type = "text/html; charset=utf-8"
  source       = "${path.module}/../front-desk/dist/index.html"
  source_hash  = local.front_desk_sha
}

resource "aws_apigatewayv2_api" "kinetic_ws_front_desk" {
  name          = "kinetic-ws-${local.env_dash}-front-desk"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "kinetic_ws_front_desk" {
  api_id = aws_apigatewayv2_api.kinetic_ws_front_desk.id

  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.kinetic_ws_front_desk_api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}


resource "aws_lambda_function" "kinetic_ws_front_desk" {
  function_name = "kinetic${local.env_dash}-workspaces-front-desk"

  timeout     = 120
  memory_size = 160
  runtime     = "nodejs18.x"
  handler     = "lambda.handler"

  filename = data.archive_file.kinetic_ws_front_desk.output_path

  source_code_hash = data.archive_file.kinetic_ws_front_desk.output_base64sha256

  role = aws_iam_role.kinetic_workspace_lambda.arn
  environment {
    variables = {
      environment       = var.environment_name,
      DYNAMO_DATA_TABLE = aws_dynamodb_table.kinetic_ws_front_desk.name,
      NODE_ENV          = "production"
    }
  }
}


resource "aws_cloudwatch_event_rule" "kinetic_ws_fd_housekeeping_every_15_minutes" {
  name                = "every-15-minutes"
  description         = "Fires every 15 minutes"
  schedule_expression = "rate(15 minutes)"
}


resource "aws_cloudwatch_event_target" "kinetic_ws_fd_housekeeping" {
  rule      = aws_cloudwatch_event_rule.kinetic_ws_fd_housekeeping_every_15_minutes.name
  target_id = aws_lambda_function.kinetic_ws_front_desk.id
  arn       = aws_lambda_function.kinetic_ws_front_desk.arn
}


resource "aws_lambda_permission" "cloudwatch_front_desk_housekeeping" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.kinetic_ws_front_desk.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.kinetic_ws_fd_housekeeping_every_15_minutes.arn
}


resource "aws_lambda_function_url" "kinetic_ws_front_desk" {
  function_name      = aws_lambda_function.kinetic_ws_front_desk.function_name
  authorization_type = "NONE"
}


resource "aws_dynamodb_table" "kinetic_ws_front_desk" {
  name           = "kinetic${local.env_dash}-front-desk"
  hash_key       = "pk"
  range_key      = "sk"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "pk"
    type = "S"
  }
  attribute {
    name = "sk"
    type = "S"
  }
}


resource "aws_dynamodb_table_item" "kinetic_ws_front_desk_config" {
  table_name = aws_dynamodb_table.kinetic_ws_front_desk.name
  hash_key   = aws_dynamodb_table.kinetic_ws_front_desk.hash_key
  range_key  = aws_dynamodb_table.kinetic_ws_front_desk.range_key
  item       = <<ITEM
  {
    "pk": {"S": "ck:kinetic_front_desk_config"},
    "sk": {"S": "${var.environment_name}"},

    "id": {"S": "kinetic_front_desk_config"},
    "status": { "S": "active" },

    "environmentName": { "S": "${var.environment_name}" },
    "ssoCookieName": { "S": "${var.sso_cookie_name}" },
    "rstudioCookieSecret": { "S": "${random_id.rstudio_cookie_key.hex}" },
    "kineticURL": { "S": "${var.kinetic_url}" },
    "editorLogin": { "S": "${var.editor_login}"},
    "editorImageSSHKey": { "S": "${urlencode(tls_private_key.kinetic_workspaces.private_key_openssh)}" },
    "efsFilesystemId": { "S": "${aws_efs_file_system.kinetic_workspaces.id}" },
    "awsRegion": { "S": "${var.aws_region}" },
    "efsAddress": { "S": "${aws_efs_file_system.kinetic_workspaces.id}.efs.${var.aws_region}.amazonaws.com" },
    "s3ConfigBucket": { "S": "${aws_s3_bucket.kinetic_workspaces_conf_files.id}" },
    "s3ArchiveBucket": { "S": "${aws_s3_bucket.kinetic_workspaces_archives.id}" },
    "dnsZoneId": { "S": "${aws_route53_zone.kinetic_workspaces.id}" },
    "dnsZoneName": { "S": "${aws_route53_zone.kinetic_workspaces.name}" },
    "enclaveSFNArn": { "S": "${aws_sfn_state_machine.kinetic_enclave.arn}" },
    "SecurityGroupIds" : { "SS": [ "${aws_security_group.kinetic_workspaces.id}" ] },
    "InstanceType": { "S": "t3a.micro" },
    "SubnetId": { "S": "${aws_subnet.kinetic_workspaces.id}" },
    "ImageId": { "S": "${data.aws_ami.kinetic_workspaces_editor.id}" },
    "KeyName": { "S": "${aws_key_pair.kinetic_workspaces.key_name}" },
    "enclaveApiKey": { "S": "${var.enclave_api_key}" }
   }
ITEM
}

resource "aws_cloudwatch_log_group" "kinetic_ws_front_desk" {
  name = "/aws/lambda/${aws_lambda_function.kinetic_ws_front_desk.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "kinetic_workspace_lambda" {
  name = "kinetic${local.env_dash}-workspace-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "kinetic_workspace_lambda" {
  name = "kinetic${local.env_dash}-workspaces-lambda"
  role = aws_iam_role.kinetic_workspace_lambda.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "APIAccessForDynamoDBStreams"
        Effect   = "Allow",
        Resource = aws_dynamodb_table.kinetic_ws_front_desk.arn,
        Action = [
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWriteItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
        ],
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = "${aws_s3_bucket.kinetic_workspaces_conf_files.arn}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketACL",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
        ],
        Resource = "${aws_s3_bucket.kinetic_workspaces_archives.arn}/*"
      },
      {
        Sid    = "AllowRunInstancesWithRestrictions"
        Effect = "Allow",
        Action = [
          "ec2:RunInstances",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeInstances",
          "ec2:TerminateInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeInstances",
          "ec2:AttachNetworkInterface"
        ],
        Resource = [
          "*"
        ],
        Effect = "Allow",
        # Condition = {
        #   StringEquals = {
        #     "ec2:ResourceTag/Application" = "KineticWorkspaces"
        #   }
        # }
      },
      {
        Effect = "Allow",
        Action = [
          "iam:PassRole",
        ],
        Resource = "arn:aws:iam::373045849756:role/kinetic_workspaces_enclave"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ],
        Resource = [
          aws_route53_zone.kinetic_workspaces.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateTags"
        ],
        Resource = "arn:aws:ec2:*:*:instance/*",
        # Condition = {
        #   StringEquals = {
        #     "ec2:CreateAction" : "RunInstances"
        #   }
        # }
      },
      {
        Effect = "Allow",
        Action = [
          "states:StartExecution",
          "states:SendTaskSuccess",
          "states:SendTaskFailure",
        ],
        Resource = aws_sfn_state_machine.kinetic_enclave.arn,
      },


      {
        Sid    = "AllowMountEFSWithRestrictions"
        Effect = "Allow",
        Action = [
          "elasticfilesystem:CreateAccessPoint",
          "elasticfilesystem:DeleteAccessPoint",
        ],
        Resource = [
          aws_efs_file_system.kinetic_workspaces.arn,
          "${aws_efs_file_system.kinetic_workspaces.arn}*",
        ],
      }
  ] })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.kinetic_workspace_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_cloudwatch_log_group" "kinetic_ws_front_desk_api_gw" {
  name = "/aws/api_gw/${aws_apigatewayv2_api.kinetic_ws_front_desk.name}"

  retention_in_days = 30
}

resource "aws_lambda_permission" "kinetic_ws_front_desk_api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.kinetic_ws_front_desk.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.kinetic_ws_front_desk.execution_arn}/*/*"
}
