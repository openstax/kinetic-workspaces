
data "aws_route53_zone" "kinetic" {
  name = var.baseDomainName
}

resource "aws_route53_zone" "kinetic_workspaces" {
  name = "workspaces.${var.baseDomainName}"
}

resource "aws_route53_record" "kinetic_workspaces_ns" {
  zone_id = data.aws_route53_zone.kinetic.zone_id
  name    = aws_route53_zone.kinetic_workspaces.name
  type    = "NS"
  ttl     = "30"
  records = aws_route53_zone.kinetic_workspaces.name_servers
}

resource "aws_acm_certificate" "kinetic_workspaces" {
  domain_name               = "${var.subDomainName}.${var.baseDomainName}"
  subject_alternative_names = ["*.${var.subDomainName}.${var.baseDomainName}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "kinetic_workspaces_cert_validation" {
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.kinetic_workspaces.domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.kinetic_workspaces.domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.kinetic_workspaces.domain_validation_options)[0].resource_record_type
  zone_id         = data.aws_route53_zone.kinetic.id
  ttl             = 60
}


resource "aws_acm_certificate_validation" "kinetic_workspaces" {
  certificate_arn         = aws_acm_certificate.kinetic_workspaces.arn
  validation_record_fqdns = ["${aws_route53_record.kinetic_workspaces_cert_validation.fqdn}"]
}

resource "aws_route53_record" "kinetic_workspaces" {
  name    = var.subDomainName # }.${var.baseDomainName}"
  type    = "A"
  zone_id = data.aws_route53_zone.kinetic.zone_id

  alias {
    name    = aws_cloudfront_distribution.kinetic_ws_url_rewriter.domain_name
    zone_id = aws_cloudfront_distribution.kinetic_ws_url_rewriter.hosted_zone_id
    evaluate_target_health = true

    # name                   = aws_apigatewayv2_domain_name.kinetic_workspaces.domain_name_configuration[0].target_domain_name
    # zone_id                = aws_apigatewayv2_domain_name.kinetic_workspaces.domain_name_configuration[0].hosted_zone_id
  }
}

# resource "aws_route53_record" "kinetic_workspaces_wildcard" {
#   name    = "*.${var.subDomainName}.${var.baseDomainName}"
#   type    = "A"
#   zone_id = data.aws_route53_zone.kinetic.zone_id

#   alias {
#     name    = aws_cloudfront_distribution.kinetic_ws_url_rewriter.domain_name
#     zone_id = aws_cloudfront_distribution.kinetic_ws_url_rewriter.hosted_zone_id
#     evaluate_target_health = true

#     # name                   = aws_apigatewayv2_domain_name.kinetic_workspaces.domain_name_configuration[0].target_domain_name
#     # zone_id                = aws_apigatewayv2_domain_name.kinetic_workspaces.domain_name_configuration[0].hosted_zone_id
#   }
# }

# resource "aws_route53_record" "kinetic_workspaces_editor" {
#   name    = "editor"
#   zone_id = data.aws_route53_zone.kinetic.zone_id
#   type    = "A"

#   alias {
#     name    = aws_cloudfront_distribution.kinetic_ws_url_rewriter.domain_name
#     zone_id = aws_cloudfront_distribution.kinetic_ws_url_rewriter.hosted_zone_id

#     evaluate_target_health = false
#   }
# }

resource "aws_route53_record" "kinetic_ws_assets" {
  name    = var.wsAssetsSubDomainName
  type    = "A"
  zone_id = data.aws_route53_zone.kinetic.zone_id

  allow_overwrite = true

  alias {
    name                   = aws_cloudfront_distribution.kinetic_ws_assets.domain_name
    zone_id                = aws_cloudfront_distribution.kinetic_ws_assets.hosted_zone_id
    evaluate_target_health = false
  }
}

output "hosted_zone_id" {
  value = aws_route53_zone.kinetic_workspaces.id
}

output "hosted_zone_name" {
  value = aws_route53_zone.kinetic_workspaces.name
}

output "workspaces_domain_name" {
  value = aws_route53_record.kinetic_workspaces.fqdn
}
