resource "aws_iam_role" "kinetic_states" {
  name = "kinetic_states"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "states.amazonaws.com"
      }
    }]
  })
}

// Attach policy to IAM Role for Step Function
resource "aws_iam_role_policy_attachment" "kinetic_invoke_states" {
  role       = aws_iam_role.kinetic_states.name
  policy_arn = aws_iam_policy.kinetic_ws_invoke_lambda.arn
}


// state machine for step function
resource "aws_sfn_state_machine" "kinetic_archive" {
  name     = "KineticWorkspacesArchive"
  role_arn = aws_iam_role.kinetic_states.arn

  definition = jsonencode({
    StartAt = "archivist"

    States = {
      archivist = {
        Comment  = "Run the archivist func."
        Type     = "Task"
        Resource = aws_lambda_function.kinetic_ws_archivist.arn
        Next     = "start_analyze_and_build"
      },
      start_analyze_and_build = {
        Comment  = "Start EC2 analyze-and-build"
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke.waitForTaskToken"

        Parameters = {
          FunctionName = aws_lambda_function.kinetic_ws_start_analyze_and_build.arn
          Payload = {
            "input.$" = "$"
            "token.$" = "$$.Task.Token"
          }
        },
        End = true
      }
    }
  })

  depends_on = [aws_lambda_function.kinetic_ws_archivist]

}


resource "null_resource" "kinetic_ws_start_analyze_and_build" {
  triggers = {
    index_ts  = base64sha256(file("${path.module}/../enclave/start-analyze-build-lambda.ts"))
    user_data = base64sha256(file("${path.module}/../enclave/ec2-user-data.sh"))
    build_ts  = base64sha256(file("${path.module}/../enclave/analyze-and-build.ts"))
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../enclave"
    command     = "./build-lambda"
  }
}

data "archive_file" "kinetic_ws_start_analyze_and_build_zip" {
  type        = "zip"
  output_path = "${path.module}/../enclave/dist/start-analyze-build-lambda.zip"
  source_file = "${path.module}/../enclave/dist/start-analyze-build-lambda.js"
  depends_on  = [null_resource.kinetic_ws_start_analyze_and_build]
}

resource "aws_s3_object" "kinetic_enclave_analyze_and_build_script" {
  bucket = aws_s3_bucket.kinetic_workspaces_conf_files.id

  key    = "scripts/analyze-and-build.js"
  source = "${path.module}/../enclave/dist/analyze-and-build.js"

  # isn't used by s3, but is needed to pickup on changes to the ts
  source_hash = filemd5("${path.module}/../enclave/analyze-and-build.ts")
  depends_on  = [null_resource.kinetic_ws_start_analyze_and_build]


}


resource "aws_lambda_function" "kinetic_ws_start_analyze_and_build" {
  function_name = "KineticWorkspacesStartAnalyzeBuild"

  filename = data.archive_file.kinetic_ws_start_analyze_and_build_zip.output_path

  # s3_bucket = aws_s3_bucket.kinetic_ws_lambda.id
  # s3_key    = "start_analyze_and_build.zip"

  timeout     = 60 # 1 minutes, is only starting a ec2 instance, doesn't wait for it to become available
  memory_size = 512
  runtime     = "nodejs18.x"
  handler     = "start-analyze-build-lambda.handler"

  source_code_hash = data.archive_file.kinetic_ws_start_analyze_and_build_zip.output_base64sha256

  vpc_config {
    subnet_ids         = [aws_subnet.kinetic_workspaces.id]
    security_group_ids = [aws_security_group.kinetic_workspaces.id]
  }
  role = aws_iam_role.kinetic_workspace_lambda.arn

  depends_on = [aws_efs_mount_target.kinetic_workspaces]
  environment {
    variables = {
      IMAGE_ID         = data.aws_ami.kinetic_enclave.id
      KEY_NAME         = aws_key_pair.kinetic_workspaces.key_name
      SUBNET_ID        = aws_subnet.kinetic_workspaces.id
      ENVIRONMENT      = var.environment_name
      BASE_IMAGE       = "${aws_ecr_repository.kinetic_workspaces.repository_url}:base"
      SECURITY_GID     = aws_security_group.kinetic_workspaces.id
      ANALYZE_SCRIPT   = "s3://${aws_s3_object.kinetic_enclave_analyze_and_build_script.bucket}/${aws_s3_object.kinetic_enclave_analyze_and_build_script.key}"
      IAM_INSTANCE_ARN = aws_iam_instance_profile.kinetic_workspaces_enclave.arn
    }
  }
}


# resource "aws_iam_role_policy" "kinetic_workspaces_enclave_lambda" {
#   name_prefix = "kinetic_workspaces-role-policy-"
#   role        = aws_iam_role.kinetic_workspaces.name

#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Sid    = "AllowRunInstancesWithRestrictions"
#         Effect = "Allow",
#         Action = [
#           "ec2:RunInstances",
#           "ec2:DescribeVpcs",
#           "ec2:DescribeSubnets",
#           "ec2:DescribeKeyPairs",
#           "ec2:DescribeInstances",
#           "ec2:TerminateInstances",
#           "ec2:DescribeInstances",
#           "ec2:DescribeSecurityGroups",
#         ],
#         Resource = [
#           "*"
#         ],
#         Effect = "Allow",
#         # Condition = {
#         #   StringEquals = {
#         #     "ec2:ResourceTag/Application" = "KineticWorkspaces"
#         #   }
#         # }
#       },
#       {
#         Effect = "Allow",
#         Action = [
#           "s3:ListBucket",
#           "s3:GetBucketACL",
#           "s3:GetBucketLocation",
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:ListMultipartUploadParts",
#           "s3:AbortMultipartUpload",
#         ],
#         Resource = "arn:aws:s3:::${aws_s3_bucket.kinetic_workspaces_archives.bucket}/*"
#       },
#     ]
#   })
# }
