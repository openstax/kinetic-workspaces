

# resource "aws_imagebuilder_component" "kinetic_workspaces_enclave" {
#   name        = "kinetic_workspaces_enclave_base"
#   platform    = "Linux"
#   version     = "1.0.0"
#   description = "My custom component for Docker image"
# }

resource "aws_imagebuilder_component" "kinetic_workspaces_enclave" {
  name     = "kinetic_workspaces_enclave"
  platform = "Linux"
  version  = "0.0.1"

  depends_on = [

  ]
  data = yamlencode({
    schemaVersion = 1.0
    phases = [{
      name = "build"
      steps = [{
        action    = "ExecuteBash"
        name      = "download_and_install_kinetic_workspaces"
        onFailure = "Abort"
        inputs = {
          commands = [
            "export DEBIAN_FRONTEND=noninteractive",
            "sudo apt-get update",
            "sudo apt-get install -y awscli",
          ]
        }
      }]
    }]
  })
}


resource "aws_imagebuilder_container_recipe" "kinetic_workspaces_enclave" {
  name = "kinetic_workspaces_enclave"

  version        = "0.0.1"
  container_type = "DOCKER"
  parent_image   = "debian:bullseye-20230411-slim"
  #amazon-linux-x86-latest/x.x.x"
  #parent_image = "arn:aws:public.ecr.aws/debian/debian:unstable-20230411-slim"
  #imagebuilder:eu-central-1:aws:image/amazon-linux-x86-latest/x.x.x"

  ### parent_image = aws_imagebuilder_component.kinetic_workspaces_enclave_parent.arn

  component {
    component_arn = aws_imagebuilder_component.kinetic_workspaces_enclave.arn
  }

  target_repository {
    repository_name = aws_ecr_repository.kinetic_workspaces.name
    service         = "ECR"
  }

  dockerfile_template_data = <<EOF
    FROM debian:bullseye
    RUN apt-get update && apt-get install -y git ruby-full build-essential awscli
    RUN aws s3 cp s3://${aws_s3_bucket.kinetic_workspaces_conf_files.id}/configs/install_r_and_pkgs /tmp/
    RUN bash /tmp/install_r_and_pkgs ${aws_s3_bucket.kinetic_workspaces_conf_files.id}
  EOF

}


resource "aws_imagebuilder_image_pipeline" "kinetic_workspaces_enclave" {
  name        = "kinetic_workspaces_enclave"
  description = "Image pipeline for building a base image for workspaces enclave"

  container_recipe_arn = aws_imagebuilder_container_recipe.kinetic_workspaces_enclave.arn

  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.kinetic_workspaces.arn

  # distribution_configuration_arn = aws_imagebuilder_distribution_configuration.kinetic_workspaces.arn
  # ecr {
  #   repository_name = aws_ecr_repository.kinetic_workspaces.name
  #   region          = var.aws_region
  # }
  #}
}


resource "aws_iam_role" "kinetic_workspaces_enclave" {
  name = "kinetic_workspaces_enclave"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "imagebuilder.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "kinetic_workspaces_enclave_image_builder" {
  name = "kinetic_workspaces_enclave"
  role = aws_iam_role.kinetic_workspaces_enclave.name
}

resource "aws_iam_policy" "kinetic_workspaces_enclave_image_builder_s3" {
  name        = "kinetic_workspaces_enclave_image_builder_s3"
  description = "Allows access to private S3 bucket"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.kinetic_workspaces_conf_files.bucket}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "kinetic_workspaces_enclave_image_builder_attachment" {
  role       = aws_iam_role.kinetic_workspaces_enclave.name
  policy_arn = aws_iam_policy.kinetic_workspaces_enclave_image_builder_s3.arn
}

output "image_pipeline_id" {
  value = aws_imagebuilder_image_pipeline.kinetic_workspaces_enclave.id
}
