

# resource "aws_imagebuilder_component" "kinetic_workspaces_enclave" {
#   name        = "kinetic_workspaces_enclave_base"
#   platform    = "Linux"
#   version     = "1.0.0"
#   description = "My custom component for Docker image"
# }



resource "aws_imagebuilder_container_recipe" "kinetic_workspaces_enclave" {
  name = "kinetic_workspaces_enclave"

  version        = "0.0.1"
  container_type = "DOCKER"
  parent_image   = "debian:bullseye-slim"

  component {
    component_arn = "arn:aws:imagebuilder:${var.aws_region}:aws:component/update-linux/x.x.x"
  }

  component {
    component_arn = aws_imagebuilder_component.kinetic_workspaces_config_files.arn
  }

  component {
    component_arn = aws_imagebuilder_component.kinetic_workspaces_install_r_and_pkgs.arn
  }

  target_repository {
    repository_name = aws_ecr_repository.kinetic_workspaces.name
    service         = "ECR"
  }

  dockerfile_template_data = <<EOF
FROM {{{ imagebuilder:parentImage }}}
{{{ imagebuilder:environments }}}
{{{ imagebuilder:components }}}
EOF

}




resource "aws_imagebuilder_image_pipeline" "kinetic_workspaces_enclave" {
  name                             = "kinetic_workspaces_enclave"
  description                      = "Image pipeline for building a base image for workspaces enclave"
  container_recipe_arn             = aws_imagebuilder_container_recipe.kinetic_workspaces_enclave.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.kinetic_workspaces.arn
}


# resource "aws_iam_role" "kinetic_workspaces_image_builder" {
#   name = "kinetic_workspaces_image_builder"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "imagebuilder.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOF
# }

resource "aws_iam_instance_profile" "kinetic_workspaces_enclave_image_builder" {
  name = "kinetic_workspaces_enclave_image_builder"
  role = aws_iam_role.kinetic_workspaces_image_builder.name
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


data "aws_ecr_image" "kinetic_workspaces_enclave" {
  repository_name = aws_ecr_repository.kinetic_workspaces.name
  most_recent     = true
}

resource "aws_iam_role_policy_attachment" "kinetic_workspaces_enclave_image_builder_attachment" {
  role       = aws_iam_role.kinetic_workspaces_image_builder.name
  policy_arn = aws_iam_policy.kinetic_workspaces_enclave_image_builder_s3.arn
}

output "image_pipeline_id" {
  value = aws_imagebuilder_image_pipeline.kinetic_workspaces_enclave.id
}
