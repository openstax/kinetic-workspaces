// state machine for step function
resource "aws_sfn_state_machine" "kinetic_enclave" {
  name = "kinetic${local.env_dash}-enclave-run"

  role_arn = aws_iam_role.kinetic_states.arn

  definition = jsonencode({
    StartAt = "archivist"

    States = {
      archivist = {
        Comment  = "Run the archivist func."
        Type     = "Task"
        Resource = aws_lambda_function.kinetic_ws_archivist.arn
        Catch = [{
          ErrorEquals = ["States.All"]
          Next        = "notify"
          ResultPath  = "$.error"
        }],
        Next = "analyze and build"
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
        Catch = [{
          ErrorEquals = ["States.All"]
          Next        = "notify"
          ResultPath  = "$.error"
        }],
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
        Catch = [{
          ErrorEquals = ["States.All"]
          Next        = "notify"
          ResultPath  = "$.error"
        }],
        Next = "notify"
      },
      "notify" = {
        Type     = "Task"
        Resource = aws_lambda_function.kinetic_ws_notify.arn
        End      = true
      }

    }
  })

  depends_on = [aws_lambda_function.kinetic_ws_archivist]
}
