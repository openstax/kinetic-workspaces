# locals {
#   archivist_archive = "${path.module}/../archivist/build/archivist.zip"
# }

# resource "aws_s3_object" "kinetic_archivist_lambda" {
#   bucket = aws_s3_bucket.kinetic_ws_lambda.id

#   key    = "archivist.zip"
#   source = local.archivist_archive
#   tags = {
#     Name = "Kinetic Workspaces Archivist"
#   }
#   etag = filemd5(local.archivist_archive)
# }

resource "aws_lambda_function" "kinetic_ws_archivist" {
  function_name = "KineticWorkspacesArchivist"

  # s3_bucket = aws_s3_bucket.kinetic_ws_lambda.id
  # s3_key    = "archivist.zip"

  timeout     = 900 # 15 minutes
  memory_size = 1024
  runtime     = "go1.x"
  handler     = "archivist"

  filename = data.archive_file.kinetic_ws_archivist_zip.output_path

  source_code_hash = data.archive_file.kinetic_ws_archivist_zip.output_base64sha256

  vpc_config {
    subnet_ids         = [aws_subnet.kinetic_workspaces.id]
    security_group_ids = [aws_security_group.kinetic_workspaces.id]
  }

  file_system_config {
    arn              = aws_efs_access_point.kinetic_workspaces.arn
    local_mount_path = "/mnt/efs"
  }

  # role = aws_iam_role.kinetic_ws_front_desk.arn
  role = aws_iam_role.kinetic_ws_archivist_lambda.arn

  depends_on = [aws_efs_mount_target.kinetic_workspaces]
  environment {
    variables = {
      environment = var.environment_name,
    }
  }
}

resource "aws_s3_bucket" "kinetic_workspaces_archives" {
  bucket = "kinetic-workspaces-archive"

  tags = {
    Name = "KineticWorkspacesArchive"
  }
}

resource "null_resource" "kinetic_ws_archivist_build" {
  triggers = {
    main_go = base64sha256(file("${path.module}/../archivist/main.go"))
  }

  provisioner "local-exec" {
    command = <<EOT
    pushd ${path.module}/../archivist && \
    GOARCH=amd64 GOOS=linux go build && \
    popd
EOT
  }
}

data "archive_file" "kinetic_ws_archivist_zip" {
  type        = "zip"
  output_path = "${path.module}/../archivist/archivist.zip"
  source_file = "${path.module}/../archivist/archivist"

  depends_on = [null_resource.kinetic_ws_archivist_build]
}

resource "aws_iam_role" "kinetic_ws_archivist_lambda" {
  name = "kinetic_ws_archivist_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "AWSLambdaVPCAccessExecutionRole" {
  role       = aws_iam_role.kinetic_ws_archivist_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "kinetic_workspaces_archivist_lambda" {
  name_prefix = "ec2-kinetic_workspaces-role-policy-"
  role        = aws_iam_role.kinetic_ws_archivist_lambda.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketACL",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
        ],
        Resource = "arn:aws:s3:::${aws_s3_bucket.kinetic_workspaces_archives.bucket}/*"
      },
    ]
  })
}

resource "aws_iam_policy" "kinetic_ws_invoke_lambda" {
  name = "kinetic_ws_archivist_lambda"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction",
                "lambda:InvokeAsync"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
