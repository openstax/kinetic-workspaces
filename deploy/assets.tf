locals {
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

  acl = "public-read"
}

resource "aws_s3_bucket_cors_configuration" "kinetic_ws_assets" {
  bucket = aws_s3_bucket.kinetic_ws_assets.id

  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
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
        "${aws_s3_bucket.kinetic_ws_assets.arn}/assets",
        "${aws_s3_bucket.kinetic_ws_assets.arn}/assets/*"
      ]
    }
  ]
}
EOF
}


// Cloudfront Distribution
resource "aws_cloudfront_distribution" "kinetic_ws_assets" {
  origin {
    domain_name = aws_s3_bucket.kinetic_ws_assets.bucket_regional_domain_name
    origin_id   = local.assets_s3_origin_id
  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = "Kinetic assets"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  aliases = ["${var.wsAssetsSubDomainName}.${var.baseDomainName}"]

  default_cache_behavior {
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    target_origin_id = local.assets_s3_origin_id

    cache_policy_id = aws_cloudfront_cache_policy.kinetic_ws_assets.id

    viewer_protocol_policy = "allow-all"
  }

  ordered_cache_behavior {
    path_pattern     = "/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.assets_s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.kinetic_workspaces.arn
    ssl_support_method  = "sni-only"
  }

}

resource "aws_cloudfront_cache_policy" "kinetic_ws_assets" {
  name = "kinetic-ws-assets"

  default_ttl = 604800 # week
  max_ttl     = 604800
  min_ttl     = 604800

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }

}


