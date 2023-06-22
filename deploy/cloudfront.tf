locals {
  assets_path         = "${path.module}/assets"
  assets_s3_origin_id = "KineticWSAssetsS3Origin"
}

## Assets Bucket
resource "aws_s3_bucket" "kinetic_ws_assets" {

  bucket = "kinetic-workspaces-assets"

  tags = {
    Name        = "kinetic-workspaces-assets"
    Environment = "all"
  }
}

resource "aws_s3_bucket_acl" "kinetic_ws_assets" {
  bucket = aws_s3_bucket.kinetic_ws_assets.id

  acl = "private"
}

resource "aws_s3_bucket_cors_configuration" "kinetic_ws_assets" {
  bucket = aws_s3_bucket.kinetic_ws_assets.id

  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
  }
}

resource "aws_s3_bucket_website_configuration" "kinetic_workspaces_editor" {
  bucket = aws_s3_bucket.kinetic_ws_assets.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_policy" "kinetic_ws_assets" {
  bucket = aws_s3_bucket.kinetic_ws_assets.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": [ "s3:GetObject" ],
      "Resource": [
        "${aws_s3_bucket.kinetic_ws_assets.arn}/*.html",
        "${aws_s3_bucket.kinetic_ws_assets.arn}/editor/*",
        "${aws_s3_bucket.kinetic_ws_assets.arn}/assets",
        "${aws_s3_bucket.kinetic_ws_assets.arn}/assets/*"
      ]
    }
  ]
}
EOF
}

resource "aws_s3_object" "kinetic_ws_rstudio_patches" {
  for_each = fileset(local.assets_path, "*")
  bucket   = aws_s3_bucket.kinetic_ws_assets.id
  key      = "assets/${each.value}"
  source   = "${local.assets_path}/${each.value}"
  etag     = filemd5("${local.assets_path}/${each.value}")
}


// Cloudfront Distribution
resource "aws_cloudfront_distribution" "kinetic_workspaces" {
  default_root_object = "index.html"

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Kinetic workspaces"

  origin {
    domain_name = aws_s3_bucket_website_configuration.kinetic_workspaces_editor.website_endpoint
    origin_id   = local.assets_s3_origin_id
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "http-only"
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  origin {
    domain_name = replace(aws_lambda_function_url.kinetic_ws_front_desk.function_url, "/^https?://([^/]*).*/", "$1")
    origin_id   = aws_lambda_function_url.kinetic_ws_front_desk.id
    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "https-only"
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = [
    local.domain_name, "*.${local.domain_name}",
  ]

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    target_origin_id = local.assets_s3_origin_id

    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # no-cache
    #  "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized

    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern     = "/status"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_lambda_function_url.kinetic_ws_front_desk.id


    compress               = true
    default_ttl            = 0
    max_ttl                = 0
    min_ttl                = 0
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      headers = [
        "Origin",
      ]
      query_string            = false
      query_string_cache_keys = []

      cookies {
        forward           = "all"
        whitelisted_names = []
      }
    }
  }

  ordered_cache_behavior {
    path_pattern     = "/editor/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.assets_s3_origin_id
    # cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # AWS caching disabled policy
    # origin_request_policy_id = "33f36d7e-f396-46d9-90e0-52428a34d9dc" # forward all
    forwarded_values {
      query_string = true
      headers      = ["Origin"]

      cookies {
        forward = "all"
      }
    }

    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.kinetic_workspaces.arn
    ssl_support_method  = "sni-only"
  }

}

