locals {
  ws_origin_id        = "KineticWSOrigin"
  ws_editor_origin_id = "KineticWSEditorOrigin"
}

resource "aws_iam_role" "kinetic_ws_lambda_edge" {
  name = "kinetic_ws_lambda_edge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
      }
    }]
  })
}

resource "aws_iam_policy" "kinetic_ws_lambda_edge_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ],
      Resource = "arn:aws:logs:*:*:*",
      Effect   = "Allow"
    }]
  })

}

resource "aws_iam_role_policy_attachment" "kinetic_ws_lambda_edge_logs" {
  role       = aws_iam_role.kinetic_ws_lambda_edge.name
  policy_arn = aws_iam_policy.kinetic_ws_lambda_edge_logging.arn
}

resource "aws_cloudwatch_log_group" "kinetic_ws_lambda_edge" {
  name              = "/aws/lambda/KineticWorkspacesEditorURLRewriter"
  retention_in_days = 7
}


data "archive_file" "editor_lambda_viewer" {
  type        = "zip"
  source_file = "./editor_lambda_viewer.js"
  output_path = "editor_lambda_viewer.zip"
}


resource "aws_lambda_function" "kinetic_ws_lambda_edge_viewer" {
  provider = aws.us_east_1

  function_name = "KineticWorkspacesEditorURLRewriterViewer"
  publish       = true
  runtime       = "nodejs18.x"
  handler       = "editor_lambda_viewer.handler"

  filename         = data.archive_file.editor_lambda_viewer.output_path
  source_code_hash = data.archive_file.editor_lambda_viewer.output_base64sha256

  role = aws_iam_role.kinetic_ws_lambda_edge.arn

  depends_on = [
    aws_iam_role_policy_attachment.kinetic_ws_lambda_edge_logs,
    aws_cloudwatch_log_group.kinetic_ws_lambda_edge,
  ]
}


data "archive_file" "editor_lambda_origin" {
  type        = "zip"
  source_file = "./editor_lambda_origin.js"
  output_path = "editor_lambda_origin.zip"
}


resource "aws_lambda_function" "kinetic_ws_lambda_edge_origin" {
  provider = aws.us_east_1

  function_name = "KineticWorkspacesEditorURLRewriterOrigin"
  publish       = true
  runtime       = "nodejs18.x"
  handler       = "editor_lambda_origin.handler"

  filename         = data.archive_file.editor_lambda_origin.output_path
  source_code_hash = data.archive_file.editor_lambda_origin.output_base64sha256

  role = aws_iam_role.kinetic_ws_lambda_edge.arn

  depends_on = [
    aws_iam_role_policy_attachment.kinetic_ws_lambda_edge_logs,
    aws_cloudwatch_log_group.kinetic_ws_lambda_edge,
  ]
}


resource "aws_cloudfront_distribution" "kinetic_ws_url_rewriter" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "Kinetic Workspaces"

  origin {
    domain_name = replace(aws_apigatewayv2_stage.kinetic_ws_front_desk.invoke_url, "/^https?://([^/]*).*/", "$1")

    // ws_apigatewayv2_domain_name.kinetic_workspaces.domain_name_configuration[0].target_domain_name
    # replace(aws_api_gateway_deployment.deployment.invoke_url, "/^https?://([^/]*).*/", "$1")

    #    domain_name = "${var.subDomainName}.${var.baseDomainName}"
    origin_id = local.ws_origin_id

    custom_origin_config {
      origin_protocol_policy = "match-viewer"
      http_port              = "80"
      https_port             = "443"
      origin_ssl_protocols   = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]

    }
  }

  aliases = [
    "${var.subDomainName}.${var.baseDomainName}",
    "*.${var.subDomainName}.${var.baseDomainName}",
  ]

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }


  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    viewer_protocol_policy = "redirect-to-https"

    target_origin_id = local.ws_origin_id

    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # AWS defined CachingDisabled
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # AWS defined AllViewerExceptHostHeader

    # origin_id = ""
    # name                   = aws_apigatewayv2_domain_name.kinetic_workspaces.domain_name_configuration[0].target_domain_name
    # zone_id                = aws_apigatewayv2_domain_name.kinetic_workspaces.domain_name_configuration[0].hosted_zone_id

    # forwarded_values {
    #   query_string = true

    #   cookies {
    #     forward = "all"
    #   }
    # }

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.kinetic_ws_lambda_edge_viewer.qualified_arn
      include_body = false
    }

    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.kinetic_ws_lambda_edge_origin.qualified_arn
      include_body = false
    }

  }


  #   # Cache behavior with precedence 0
  #   ordered_cache_behavior {
  #     path_pattern     = "/editor/*"
  #     target_origin_id = local.ws_editor_origin_id

  #     lambda_function_association {
  #       event_type = "origin-request"
  #       lambda_arn = "${aws_lambda_function.kinetic_ws_lambda_edge.qualified_arn}"
  #     }

  #     allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
  #     cached_methods   = ["GET", "HEAD"]

  # //    target_origin_id = local.s3_origin_id

  #     forwarded_values {
  #       query_string = true

  #       cookies {
  #         forward = "all"
  #       }
  #     }

  #     viewer_protocol_policy = "redirect-to-https"
  #   }



  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.kinetic_workspaces.arn
    ssl_support_method  = "sni-only"
  }

}

output "api_domain_name" {
  value = replace(aws_apigatewayv2_stage.kinetic_ws_front_desk.invoke_url, "/^https?://([^/]*).*/", "$1")
}
