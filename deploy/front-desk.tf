# data "archive_file" "kinetic_ws_front_desk" {
#   type = "zip"

#   source_dir  = "${path.module}/../front-desk"
#   output_path = "${path.module}/kinetic-workspaces-front-desk.zip"
#   # excludes = ["dist/client"]
# }

locals {
  front_desk_archive = "${path.module}/../front-desk/lambda/bundled.zip"
}

# resource "null_resource" "build_front_desk_lambda" {
#   triggers = {

#   }

#   provisioner "local-exec" {
#     command = "cd ../front-desk && ./bin/build"
#   }
# }

resource "aws_s3_object" "kinetic_ws_front_desk_lambda" {
  bucket = aws_s3_bucket.kinetic_ws_front_desk_lambda.id

  key    = "front-desk.zip"
  source = local.front_desk_archive
  tags = {
    Name = "Kinetic Workspaces Front Desk"
  }
  #  data.archive_file.kinetic_ws_front_desk.output_path

  etag = filemd5(local.front_desk_archive)
}

resource "aws_s3_bucket" "kinetic_ws_front_desk_lambda" {
  bucket = "kinetic-workspaces-lambdas"
}

resource "aws_s3_bucket_acl" "kinetic_lambda" {
  bucket = aws_s3_bucket.kinetic_ws_front_desk_lambda.id
  acl    = "private"
}

resource "aws_apigatewayv2_api" "kinetic_ws_front_desk" {
  name          = "kinetic-ws-front-desk"
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
      }
    )
  }
}


resource "aws_lambda_function" "kinetic_ws_front_desk" {
  function_name = "KineticWorkspacesFrontDesk"

  s3_bucket = aws_s3_bucket.kinetic_ws_front_desk_lambda.id
  s3_key    = aws_s3_object.kinetic_ws_front_desk_lambda.key

  timeout = 120
  runtime = "nodejs18.x"
  handler = "lambda.handler"

  source_code_hash = filebase64sha256(local.front_desk_archive)

  role = aws_iam_role.kinetic_ws_front_desk.arn
  environment {
    variables = {
      environment = var.environment_name,
      NODE_ENV    = "production"
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
  name           = "KineticWSFrontDesk"
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
    "ssoCookiePublicKey": { "S": "${urlencode(var.sso_cookie_public_key)}" },
    "ssoCookiePrivateKey": { "S": "${urlencode(var.sso_cookie_private_key)}" },
    "rstudioCookieSecret": { "S": "${random_id.rstudio_cookie_key.hex}" },
    "kineticURL": { "S": "${var.kinetic_url}" },
    "editorLogin": { "S": "${var.editor_login}"},
    "editorImageSSHKey": { "S": "${urlencode(tls_private_key.kinetic_workspaces.private_key_openssh)}" },
    "efsFilesystemId": { "S": "${aws_efs_file_system.kinetic_workspaces.id}" },
    "awsRegion": { "S": "${var.aws_region}" },
    "efsAddress": { "S": "${aws_efs_file_system.kinetic_workspaces.id}.efs.${var.aws_region}.amazonaws.com" },
    "s3ConfigBucket": { "S": "${aws_s3_bucket.kinetic_workspaces_conf_files.id}" },
    "dnsZoneId": { "S": "${aws_route53_zone.kinetic_workspaces.id}" },
    "dnsZoneName": { "S": "${aws_route53_zone.kinetic_workspaces.name}" },

    "SecurityGroupIds" : { "SS": [ "${aws_security_group.ec2_kinetic_workspaces.id}" ] },
    "InstanceType": { "S": "t3a.micro" },
    "SubnetId": { "S": "${aws_subnet.kinetic_workspaces.id}" },
    "ImageId": { "S": "${data.aws_ami.kinetic_workspaces.id}" },
    "KeyName": { "S": "${aws_key_pair.kinetic_workspaces.key_name}" }
   }
ITEM
}

resource "aws_cloudwatch_log_group" "kinetic_ws_front_desk" {
  name = "/aws/lambda/${aws_lambda_function.kinetic_ws_front_desk.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "kinetic_ws_front_desk" {
  name = "kinetic_ws_front_desk"

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

resource "aws_iam_role_policy" "kinetic_ws_front_desk_db" {
  name = "kinetic_ws_front_desk_db"
  role = aws_iam_role.kinetic_ws_front_desk.id
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
          "s3:GetObject"
        ],
        Resource = "${aws_s3_bucket.kinetic_workspaces_conf_files.arn}/*"
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
        Sid    = "AllowMountEFSWithRestrictions"
        Effect = "Allow",
        Action = [
          "elasticfilesystem:CreateAccessPoint",
          "elasticfilesystem:DeleteAccessPoint",
        ],
        Resource = [
          "*"
          # doesn't work fro delete
          #aws_efs_file_system.kinetic_workspaces.arn
        ],
        # Effect = "Allow",
        # Condition = {
        #   StringEquals = {
        #     "elasticfilesystem:AccessPointArn" = "KineticWorkspaces"
        #   }
        # }
      }
  ] })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.kinetic_ws_front_desk.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}




# {
#       Sid = "FunctionURLAllowPublicAccess",
#      Effect = "Allow",
#      Principal = "*",
#      Action = "lambda:InvokeFunctionUrl",
#      Resource = aws_iam_role.kinetic_ws_front_desk.arn
#      Condition = {
#        StringEquals = {
#          "lambda:FunctionUrlAuthType" = "NONE"
#        }
#      }
#    }

# resource "aws_apigatewayv2_integration" "kinetic_ws_front_desk" {
#   api_id = aws_apigatewayv2_api.kinetic_ws_front_desk.id

#   integration_uri    = aws_lambda_function.kinetic_ws_front_desk.invoke_arn
#   integration_type   = "AWS_PROXY"
#   integration_method = "POST"
# }



# resource "aws_apigatewayv2_route" "kinetic_ws_front_desk" {
#   api_id = aws_apigatewayv2_api.kinetic_ws_front_desk.id

#   route_key = "$default"
#   target    = "integrations/${aws_apigatewayv2_integration.kinetic_ws_front_desk.id}"
# }

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


# resource "aws_apigatewayv2_domain_name" "kinetic_workspaces" {
#   domain_name = "${var.subDomainName}.${var.baseDomainName}"

#   domain_name_configuration {
#     certificate_arn = aws_acm_certificate.kinetic_workspaces.arn
#     endpoint_type   = "REGIONAL"
#     security_policy = "TLS_1_2"
#   }

#   depends_on = [aws_acm_certificate_validation.kinetic_workspaces]
# }

# resource "aws_apigatewayv2_api_mapping" "kinetic_workspaces" {
#   stage       = aws_apigatewayv2_stage.kinetic_ws_front_desk.id
#   api_id      = aws_apigatewayv2_api.kinetic_ws_front_desk.id
#   domain_name = aws_apigatewayv2_domain_name.kinetic_workspaces.id
# }

output "kinetic_workspaces_front_desk_url" {
  description = "URL for API lambda stage."
  value       = aws_lambda_function_url.kinetic_ws_front_desk.function_url
}

# output "front_desk_invoke_url" {
#   value = aws_apigatewayv2_stage.kinetic_ws_front_desk.invoke_url
# }


output "front_desk_config_entry" {
  value     = aws_dynamodb_table_item.kinetic_ws_front_desk_config.item
  sensitive = true
}
