output "workspaces_ecr_repository_url" {
  value = aws_ecr_repository.kinetic_workspaces.repository_url
}

output "workspaces_vpc_id" {
  value = aws_vpc.kinetic_workspaces.id
}

output "workspaces_subnet_id" {
  value = aws_subnet.kinetic_workspaces.id
}

output "editor_ami_id" {
  value = data.aws_ami.kinetic_workspaces_editor.id
}

output "workspaces_security_group_id" {
  value = aws_security_group.kinetic_workspaces.id
}

output "workspaces_ssh_key_pem" {
  value     = tls_private_key.kinetic_workspaces.private_key_openssh
  sensitive = true
}

output "kinetic_workspaces_front_desk_url" {
  description = "URL for API lambda stage."
  value       = aws_lambda_function_url.kinetic_ws_front_desk.function_url
}

output "front_desk_config_entry" {
  value     = aws_dynamodb_table_item.kinetic_ws_front_desk_config.item
  sensitive = true
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
