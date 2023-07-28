resource "aws_lambda_function" "kinetic_survey_sweeper" {
  function_name = "kinetic${local.env_dash}-survey-sweeper"
  timeout       = 120
  memory_size   = 1536
  package_type  = "Image"

  # image_uri = docker_image.survey_sweeper.name #image_uri
  #"${aws_ecr_repository.kinetic_workspaces.repository_url}:survey-sweeper"
  image_uri = tolist(tolist(aws_imagebuilder_image.kinetic_survey_sweeper.output_resources[0].containers)[0].image_uris)[0]
  role      = aws_iam_role.kinetic_workspace_lambda.arn
  environment {
    variables = {
      HOME              = "/app"
      SCRIPT_BUCKET     = aws_s3_bucket.kinetic_workspaces_conf_files.bucket
      R_SCRIPT_PATH     = aws_s3_object.qualtrics_fetch_and_process.key,
      environment       = var.environment_name,
      DYNAMO_DATA_TABLE = aws_dynamodb_table.kinetic_ws_front_desk.name,
      NODE_ENV          = "production"
      QUALTRICS_API_KEY = var.qualtrics_api_key
    }
  }
}


resource "aws_imagebuilder_distribution_configuration" "kinetic_survey_sweeper" {
  name = "kinetic${local.env_dash}-survey-sweeper"

  distribution {
    region = var.aws_region
    container_distribution_configuration {

      target_repository {
        repository_name = aws_ecr_repository.kinetic_workspaces.name
        service         = "ECR"
      }
    }
  }
}


resource "aws_imagebuilder_container_recipe" "kinetic_survey_sweeper" {
  name = "kinetic${local.env_dash}-survey-sweeper"

  version        = "0.0.1"
  container_type = "DOCKER"
  parent_image   = "ubuntu:jammy"

  component {
    component_arn = aws_imagebuilder_component.kinetic_survey_sweeper.arn
  }

  target_repository {
    repository_name = aws_ecr_repository.kinetic_workspaces.name
    service         = "ECR"
  }

  dockerfile_template_data = <<-EOF
  FROM {{{ imagebuilder:parentImage }}}
  {{{ imagebuilder:environments }}}
  {{{ imagebuilder:components }}}
  WORKDIR /app
  ENTRYPOINT ["node_modules/.bin/aws-lambda-ric"]
  CMD ["index.handler"]
  EOF
}


resource "aws_s3_object" "qualtrics_fetch_and_process" {
  bucket      = aws_s3_bucket.kinetic_workspaces_conf_files.id
  key         = "scripts/qualtrics-fetch-and-process.R"
  source      = "${path.module}/../enclave/qualtrics-fetch-and-process.R"
  source_hash = filemd5("${path.module}/../enclave/qualtrics-fetch-and-process.R")
}


resource "aws_imagebuilder_image_pipeline" "kinetic_survey_sweeper" {
  name                             = "kinetic${local.env_dash}-survey-sweeper"
  description                      = "Image pipeline for building the survey sweeper lambda image"
  container_recipe_arn             = aws_imagebuilder_container_recipe.kinetic_survey_sweeper.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.kinetic_workspaces.arn
}

resource "aws_imagebuilder_image" "kinetic_survey_sweeper" {
  container_recipe_arn             = aws_imagebuilder_container_recipe.kinetic_survey_sweeper.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.kinetic_workspaces.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.kinetic_survey_sweeper.arn
}
