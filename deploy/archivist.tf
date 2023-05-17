locals {
  archivist_archive = "${path.module}/../archivist/build/archivist.zip"
}

resource "aws_s3_object" "kinetic_archivist_lambda" {
  bucket = aws_s3_bucket.kinetic_ws_lambda.id

  key    = "archivist.zip"
  source = local.archivist_archive
  tags = {
    Name = "Kinetic Workspaces Archivist"
  }
  etag = filemd5(local.archivist_archive)
}

resource "aws_lambda_function" "kinetic_ws_archivist" {
  function_name = "KineticWorkspacesArchivist"

  s3_bucket = aws_s3_bucket.kinetic_ws_lambda.id
  s3_key    = "archivist.zip"

  timeout     = 900 # 15 minutes
  memory_size = 1024
  runtime     = "go1.x"
  handler     = "archivist"

  source_code_hash = filebase64sha256(local.archivist_archive)

  vpc_config {
    subnet_ids         = [aws_subnet.kinetic_workspaces.id]
    security_group_ids = [aws_security_group.ec2_kinetic_workspaces.id]
  }

  file_system_config {
    arn              = aws_efs_access_point.kinetic_workspaces.arn
    local_mount_path = "/mnt/efs"
  }

  role       = aws_iam_role.kinetic_ws_archivist_lambda.arn
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

resource "aws_iam_role" "kinetic_ws_archivist_states" {
  name = "kinetic_ws_archivist_states"

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

// Attach policy to IAM Role for Step Function
resource "aws_iam_role_policy_attachment" "kinetic_ws_archivist_invoke_lambda" {
  role       = aws_iam_role.kinetic_ws_archivist_states.name
  policy_arn = aws_iam_policy.kinetic_ws_invoke_lambda.arn
}



// Create state machine for step function
resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = "KineticWorkspacesArchive"
  role_arn = aws_iam_role.kinetic_ws_archivist_states.arn

  definition = <<EOF
{
  "StartAt": "kinetic_ws_archivist",
  "States": {

    "kinetic_ws_archivist": {
      "Comment": "Run the archivist func.",
      "Type": "Task",
      "Resource": "${aws_lambda_function.kinetic_ws_archivist.arn}",
      "Next": "send-notification"
    },

    "send-notification": {
      "Comment": "Trigger notification using AWS SNS",
      "Type": "Parallel",
      "End": true,
      "Branches": [
        {
         "StartAt": "send-sms-notification",
         "States": {
            "send-sms-notification": {
              "Type": "Task",
              "Resource": "arn:aws:states:::sns:publish",
              "Parameters": {
                "Message": "SMS: Comlpeted $",
                "PhoneNumber": "${var.email_address_notification}"
              },
              "End": true
            }
         }
       }]
    }
  }
}
EOF

  depends_on = [aws_lambda_function.kinetic_ws_archivist]

}
