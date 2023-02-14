data "archive_file" "kinetic_ws_front_desk" {
  type = "zip"

  source_dir  = "${path.module}/../front-desk"
  output_path = "${path.module}/kinetic-workspaces-front-desk.zip"
}

resource "aws_s3_object" "kinetic_ws_front_desk_lambda" {
  bucket = aws_s3_bucket.kinetic_ws_front_desk_lambda.id

  key    = "kinetic-workspaces-front-desk.zip"
  source = data.archive_file.kinetic_ws_front_desk.output_path

  etag = filemd5(data.archive_file.kinetic_ws_front_desk.output_path)
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

  name        = "serverless_lambda_stage"
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
  function_name = "HelloWorld"

  s3_bucket = aws_s3_bucket.kinetic_ws_front_desk_lambda.id
  s3_key    = aws_s3_object.kinetic_ws_front_desk_lambda.key

  runtime = "nodejs18.x"
  handler = "main.handler"

  source_code_hash = data.archive_file.kinetic_ws_front_desk.output_base64sha256

  role = aws_iam_role.kinetic_ws_front_desk_exec.arn
}

resource "aws_cloudwatch_log_group" "kinetic_ws_front_desk" {
  name = "/aws/lambda/${aws_lambda_function.kinetic_ws_front_desk.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "kinetic_ws_front_desk_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.kinetic_ws_front_desk_exec.name
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


resource "aws_apigatewayv2_domain_name" "kinetic_workspaces" {
  domain_name = "${var.subDomainName}.${var.baseDomainName}"

  domain_name_configuration {
    certificate_arn = aws_acm_certificate.kinetic_workspaces.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  depends_on = [aws_acm_certificate_validation.kinetic_workspaces]
}

resource "aws_apigatewayv2_api_mapping" "kinetic_workspaces" {
  stage       = aws_apigatewayv2_stage.kinetic_ws_front_desk.id
  api_id      = aws_apigatewayv2_api.kinetic_ws_front_desk.id
  domain_name = aws_apigatewayv2_domain_name.kinetic_workspaces.id
}

output "kinetic_workspaces_front_desk_url" {
  description = "URL for API Gateway stage."
  value       = "https://${var.subDomainName}.${var.baseDomainName}/"
}
