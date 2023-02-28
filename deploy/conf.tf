resource "aws_s3_bucket" "kinetic_workspaces_conf_files" {
  bucket = "kinetic-workspaces-config"


  tags = {
    Name        = "KineticWorkspacesConfig"
  }
}


resource "aws_s3_bucket_object" "kinetic_workspaces_conf_files" {
  for_each = fileset("${path.module}/configs/", "*")
  bucket   = aws_s3_bucket.kinetic_workspaces_conf_files.id
  key      = each.value
  source   = "${path.module}/configs/${each.value}"
  etag     = filemd5("${path.module}/configs/${each.value}")
}
