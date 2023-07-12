resource "aws_imagebuilder_distribution_configuration" "kinetic_enclave_ami" {
  name = "kinetic${local.env_dash}-enclave-ami"

  distribution {
    ami_distribution_configuration {
      name = "kinetic_enclave-{{ imagebuilder:buildDate }}"
    }

    region = var.aws_region
  }
}

resource "aws_imagebuilder_image_pipeline" "kinetic_enclave" {
  name             = "kinetic${local.env_dash}-enclave"
  image_recipe_arn = aws_imagebuilder_image_recipe.kinetic_enclave.arn

  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.kinetic_workspaces.arn
}

resource "aws_imagebuilder_image_recipe" "kinetic_enclave" {
  name = "kinetic${local.env_dash}-enclave"

  component {
    component_arn = aws_imagebuilder_component.kinetic_workspaces_base_config.arn
  }
  component {
    component_arn = aws_imagebuilder_component.kinetic_install_docker_build.arn
  }

  parent_image = data.aws_ami.kinetic_workspaces_parent_image.id
  version      = "1.0.0"
}

resource "aws_imagebuilder_image" "kinetic_enclave" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.kinetic_enclave.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.kinetic_workspaces.arn
  enhanced_image_metadata_enabled  = true
}

data "aws_ami" "kinetic_enclave" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [aws_imagebuilder_image.kinetic_enclave.name, "${aws_imagebuilder_image.kinetic_enclave.name}*"]
  }
}
