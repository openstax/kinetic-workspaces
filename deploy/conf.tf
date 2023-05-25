locals {
  config_path    = "${path.module}/configs"
  provision_path = "${path.module}/provision"
}

resource "aws_s3_bucket" "kinetic_workspaces_conf_files" {
  bucket = "kinetic-workspaces-config"

  tags = {
    Name = "KineticWorkspacesConfig"
  }
}

resource "aws_s3_bucket_acl" "kinetic_workspaces_conf_files" {
  bucket = aws_s3_bucket.kinetic_workspaces_conf_files.id

  acl = "private"
}

resource "aws_s3_object" "kinetic_workspaces_conf_files" {
  for_each    = fileset(local.config_path, "*")
  bucket      = aws_s3_bucket.kinetic_workspaces_conf_files.id
  key         = "/configs/${each.value}"
  source      = "${local.config_path}/${each.value}"
  source_hash = filemd5("${local.config_path}/${each.value}")
}

resource "aws_s3_object" "kinetic_workspaces_provisioning_files" {
  for_each    = fileset(local.provision_path, "*")
  bucket      = aws_s3_bucket.kinetic_workspaces_conf_files.id
  key         = "/provision/${each.value}"
  source      = "${local.provision_path}/${each.value}"
  source_hash = filemd5("${local.provision_path}/${each.value}")
}
