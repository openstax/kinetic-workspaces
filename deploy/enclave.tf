resource "aws_iam_role" "kinetic_states" {
  name = "kinetic${local.env_dash}-states"

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

resource "aws_iam_role_policy_attachment" "kinetic_invoke_states" {
  role       = aws_iam_role.kinetic_states.name
  policy_arn = aws_iam_policy.kinetic_ws_invoke_lambda.arn
}

resource "aws_iam_policy" "kinetic_ws_invoke_lambda" {
  name = "kinetic_ws_enclave_lambda_invoke"

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




resource "null_resource" "kinetic_ws_enclave_ts" {
  triggers = {
    run_task_ts = base64sha256(file("${path.module}/../enclave/run-ec2-task.ts"))
    notify_ts   = base64sha256(file("${path.module}/../enclave/notify.ts"))
    user_data   = base64sha256(file("${path.module}/../enclave/ec2-user-data.sh"))
    build_ts    = base64sha256(file("${path.module}/../enclave/analyze-and-build.ts"))
    ec_run_ts   = base64sha256(file("${path.module}/../enclave/enclave-run.ts"))
    shared_ts   = base64sha256(file("${path.module}/../enclave/shared.ts"))
    sweeper_ts  = base64sha256(file("${path.module}/../enclave/survey-sweeper.ts"))
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../enclave"
    command     = "./build-ts"
  }
}

resource "aws_s3_object" "kinetic_lambdas" {
  for_each    = fileset(local.enclave_path, "*")
  bucket      = aws_s3_bucket.kinetic_workspaces_conf_files.id
  key         = "/lambda/${each.value}"
  source      = "${local.enclave_path}/${each.value}"
  source_hash = filemd5("${local.enclave_path}/${each.value}")
}


data "archive_file" "kinetic_ws_run_ec2_task_zip" {
  type        = "zip"
  output_path = "${path.module}/../enclave/dist/run-ec2-task.zip"
  source_file = "${path.module}/../enclave/dist/run-ec2-task.js"
  depends_on  = [null_resource.kinetic_ws_enclave_ts]
}

data "archive_file" "kinetic_ws_notify_zip" {
  type        = "zip"
  output_path = "${path.module}/../enclave/dist/notify.zip"
  source_file = "${path.module}/../enclave/dist/notify.js"
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
  function_name = "kinetic${local.env_dash}-workspaces-run-ec2-task"

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


resource "aws_lambda_function" "kinetic_ws_notify" {
  function_name = "kinetic${local.env_dash}-workspaces-notify"

  filename = data.archive_file.kinetic_ws_notify_zip.output_path

  timeout     = 60 # 1 minutes, is only starting a ec2 instance, doesn't wait for it to become available
  memory_size = 512
  runtime     = "nodejs18.x"
  handler     = "notify.handler"

  source_code_hash = data.archive_file.kinetic_ws_notify_zip.output_base64sha256
  role             = aws_iam_role.kinetic_workspace_lambda.arn
}
