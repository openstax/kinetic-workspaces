# data "archive_file" "kinetic_ws_front_desk" {
#   type = "zip"

#   source_dir  = "${path.module}/../front-desk"
#   output_path = "${path.module}/kinetic-workspaces-front-desk.zip"
#   # excludes = ["dist/client"]
# }

locals {
  front_desk_archive = "${path.module}/../front-desk/archive.zip"
}

resource "aws_s3_object" "kinetic_ws_front_desk_lambda" {
  bucket = aws_s3_bucket.kinetic_ws_front_desk_lambda.id

  key    = "kinetic-workspaces-front-desk.zip"
  source = local.front_desk_archive
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
  name          = "kinetic_ws_front_desk_lambda_gw"
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


resource "aws_dynamodb_table" "kinetic_ws_front_desk" {
  name             = "KineticWSFrontDesk"
  hash_key         = "id"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  attribute {
    name = "id"
    type = "S"
  }
}


resource "aws_lambda_function" "kinetic_ws_front_desk" {
  function_name = "KineticWorkspacesFrontDesk"

  s3_bucket = aws_s3_bucket.kinetic_ws_front_desk_lambda.id
  s3_key    = aws_s3_object.kinetic_ws_front_desk_lambda.key

  runtime = "nodejs18.x"
  handler = "index.handler"

  source_code_hash = filebase64sha256(local.front_desk_archive)

  role = aws_iam_role.kinetic_ws_front_desk.arn
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
  name   = "kinetic_ws_front_desk_db"
  role   = aws_iam_role.kinetic_ws_front_desk.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [ {
      Sid = "APIAccessForDynamoDBStreams"
      Effect = "Allow",
      Resource = aws_dynamodb_table.kinetic_ws_front_desk.arn,
      Action = [
        "dynamodb:BatchGetItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
      ],
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.kinetic_ws_front_desk.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_apigatewayv2_integration" "kinetic_ws_front_desk" {
  api_id = aws_apigatewayv2_api.kinetic_ws_front_desk.id

  integration_uri    = aws_lambda_function.kinetic_ws_front_desk.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "kinetic_ws_front_desk" {
  api_id = aws_apigatewayv2_api.kinetic_ws_front_desk.id

  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.kinetic_ws_front_desk.id}"
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
  description = "URL for API Gateway stage."
  value       = "https://${var.subDomainName}.${var.baseDomainName}/"
}

output "front_desk_invoke_url" {
  value = aws_apigatewayv2_stage.kinetic_ws_front_desk.invoke_url
}


