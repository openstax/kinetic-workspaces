
data "aws_route53_zone" "kinetic" {
  name = var.baseDomainName
}

resource "aws_acm_certificate" "kinetic_workspaces" {
  domain_name = var.baseDomainName
  subject_alternative_names = ["*.${var.baseDomainName}"]
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "kinetic_workspaces_cert_validation" {
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.kinetic_workspaces.domain_validation_options)[0].resource_record_name
  records         = [ tolist(aws_acm_certificate.kinetic_workspaces.domain_validation_options)[0].resource_record_value ]
  type            = tolist(aws_acm_certificate.kinetic_workspaces.domain_validation_options)[0].resource_record_type
  zone_id  = data.aws_route53_zone.kinetic.id
  ttl      = 60
}


resource "aws_acm_certificate_validation" "kinetic_workspaces" {
  certificate_arn         = aws_acm_certificate.kinetic_workspaces.arn
  validation_record_fqdns = ["${aws_route53_record.kinetic_workspaces_cert_validation.fqdn}"]
}

resource "aws_route53_record" "kinetic_workspaces" {
  name    = aws_apigatewayv2_domain_name.kinetic_workspaces.domain_name
  type    = "A"
  zone_id = data.aws_route53_zone.kinetic.zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.kinetic_workspaces.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.kinetic_workspaces.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
