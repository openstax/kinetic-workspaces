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
        Next     = "analyze and build"
      },
      "analyze and build" = {
        Comment  = "Start EC2 analyze-and-build"
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke.waitForTaskToken"

        Parameters = {
          FunctionName = aws_lambda_function.kinetic_ws_run_ec2_task.arn
          Payload = {
            "input.$" = "$"
            "token.$" = "$$.Task.Token"
            "script"  = "s3://${aws_s3_object.kinetic_enclave_analyze_and_build_script.bucket}/${aws_s3_object.kinetic_enclave_analyze_and_build_script.key}"
          }
        },
        Next = "run enclave" # TODO: add a pause for manual review
      },
      "run enclave" = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke.waitForTaskToken"

        Parameters = {
          FunctionName = aws_lambda_function.kinetic_ws_run_ec2_task.arn
          Payload = {
            "input.$" = "$"
            "token.$" = "$$.Task.Token"
            "script"  = "s3://${aws_s3_object.kinetic_enclave_run_script.bucket}/${aws_s3_object.kinetic_enclave_run_script.key}"
          }
        },
        End = true
      }
    }
  })

  depends_on = [aws_lambda_function.kinetic_ws_archivist]
}


resource "null_resource" "kinetic_ws_enclave_ts" {
  triggers = {
    run_task_ts = base64sha256(file("${path.module}/../enclave/run-ec2-task.ts"))
    user_data   = base64sha256(file("${path.module}/../enclave/ec2-user-data.sh"))
    build_ts    = base64sha256(file("${path.module}/../enclave/analyze-and-build.ts"))
    ec_run_ts   = base64sha256(file("${path.module}/../enclave/enclave-run.ts"))
    shared_ts   = base64sha256(file("${path.module}/../enclave/shared.ts"))
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../enclave"
    command     = "./build-ts"
  }
}

data "archive_file" "kinetic_ws_run_ec2_task_zip" {
  type        = "zip"
  output_path = "${path.module}/../enclave/dist/run-ec2-task.zip"
  source_file = "${path.module}/../enclave/dist/run-ec2-task.js"
  depends_on  = [null_resource.kinetic_ws_enclave_ts]
}

resource "aws_s3_object" "kinetic_enclave_run_script" {
  bucket = aws_s3_bucket.kinetic_workspaces_conf_files.id
  key    = "scripts/enclave-run.js"
  source = "${path.module}/../enclave/dist/enclave-run.js"
  # isn't used by s3, but is needed to pickup on changes to the ts
  source_hash = filemd5("${path.module}/../enclave/enclave-run.ts")
  depends_on  = [null_resource.kinetic_ws_enclave_ts]
}

resource "aws_s3_object" "kinetic_enclave_analyze_and_build_script" {
  bucket = aws_s3_bucket.kinetic_workspaces_conf_files.id
  key    = "scripts/analyze-and-build.js"
  source = "${path.module}/../enclave/dist/analyze-and-build.js"
  # isn't used by s3, but is needed to pickup on changes to the ts
  source_hash = filemd5("${path.module}/../enclave/analyze-and-build.ts")
  depends_on  = [null_resource.kinetic_ws_enclave_ts]
}


resource "aws_lambda_function" "kinetic_ws_run_ec2_task" {
  function_name = "KineticWorkspacesRunEc2Task"

  filename = data.archive_file.kinetic_ws_run_ec2_task_zip.output_path

  timeout     = 60 # 1 minutes, is only starting a ec2 instance, doesn't wait for it to become available
  memory_size = 512
  runtime     = "nodejs18.x"
  handler     = "run-ec2-task.handler"

  source_code_hash = data.archive_file.kinetic_ws_run_ec2_task_zip.output_base64sha256

  vpc_config {
    subnet_ids         = [aws_subnet.kinetic_workspaces.id]
    security_group_ids = [aws_security_group.kinetic_workspaces.id]
  }
  role = aws_iam_role.kinetic_workspace_lambda.arn

  environment {
    variables = {
      IMAGE_ID         = data.aws_ami.kinetic_enclave.id
      KEY_NAME         = aws_key_pair.kinetic_workspaces.key_name
      SUBNET_ID        = aws_subnet.kinetic_workspaces.id
      ENVIRONMENT      = var.environment_name
      BASE_IMAGE       = "${aws_ecr_repository.kinetic_workspaces.repository_url}:base"
      SECURITY_GID     = aws_security_group.kinetic_workspaces.id
      IAM_INSTANCE_ARN = aws_iam_instance_profile.kinetic_workspaces_enclave.arn
    }
  }
}

