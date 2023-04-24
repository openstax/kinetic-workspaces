locals {
  config_path = "${path.module}/configs"
  # flatten([for d in flatten(fileset("${path.module}/configs/*", "*")) : trim(d, "../")])
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


resource "aws_s3_bucket_lifecycle_configuration" "kinetic_workspaces_conf_cached_files" {
  bucket = aws_s3_bucket.kinetic_workspaces_conf_files.id
  rule {
    id     = "cache"
    status = "Enabled"
    filter {
      prefix = "cache/"
    }
    expiration {
      # letsencrypt expires arter 90, renew at midpoint to expiry
      days = 45
    }
  }
}

resource "aws_s3_object" "kinetic_workspaces_conf_files" {
  for_each    = fileset(local.config_path, "*")
  bucket      = aws_s3_bucket.kinetic_workspaces_conf_files.id
  key         = "/configs/${each.value}"
  source      = "${local.config_path}/${each.value}"
  source_hash = filemd5("${local.config_path}/${each.value}")
}
