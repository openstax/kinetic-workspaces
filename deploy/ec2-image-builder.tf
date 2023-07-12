data "aws_ami" "kinetic_workspaces_editor" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [aws_imagebuilder_image.kinetic_workspaces_editor.name, "${aws_imagebuilder_image.kinetic_workspaces_editor.name}*"]
  }
}

data "aws_ami" "kinetic_workspaces_parent_image" {
  most_recent = true
  owners      = ["099720109477"] // ubuntu
  filter {
    name   = "name"
    values = ["*ubuntu-jammy-*20230516"] # ubuntu images update A LOT.  Date included to prevent picking up a newer image until we're ready
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_partition" "current" {}

resource "aws_imagebuilder_image_pipeline" "kinetic_workspaces_editor" {
  name                             = "kinetic_workspaces_image_pipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.kinetic_workspaces_editor.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.kinetic_workspaces.arn
}


resource "aws_imagebuilder_image_recipe" "kinetic_workspaces_editor" {
  name = "kinetic${local.env_dash}-workspaces-editor"

  component {
    component_arn = aws_imagebuilder_component.kinetic_workspaces_base_config.arn
  }

  component {
    component_arn = aws_imagebuilder_component.kinetic_workspaces_install_r.arn
  }

  component {
    component_arn = aws_imagebuilder_component.kinetic_workspaces_editor.arn
  }

  parent_image = data.aws_ami.kinetic_workspaces_parent_image.id
  version      = "1.0.0"
}

resource "aws_imagebuilder_distribution_configuration" "kinetic_workspaces" {
  name = "kinetic${local.env_dash}-workspaces-distribution-configuration"

  distribution {
    ami_distribution_configuration {
      name = "kinetic_workspaces-{{ imagebuilder:buildDate }}"
    }

    region = var.aws_region
  }
}


# To force regeneration run:
# terraform apply -replace=aws_imagebuilder_image.kinetic_workspaces
resource "aws_imagebuilder_image" "kinetic_workspaces_editor" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.kinetic_workspaces_editor.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.kinetic_workspaces.arn
  enhanced_image_metadata_enabled  = true
}

resource "aws_imagebuilder_infrastructure_configuration" "kinetic_workspaces" {
  name                          = "kinetic_workspaces_infrastructure_configuration"
  description                   = "AWS image builder config for EC2 with Kinetic_Workspaces hosted"
  instance_profile_name         = aws_iam_instance_profile.kinetic_workspaces_image_builder.name
  instance_types                = ["t3.xlarge"] # using a 2xlarge to speed up builds
  security_group_ids            = [aws_security_group.kinetic_workspaces.id]
  subnet_id                     = aws_subnet.kinetic_workspaces.id
  terminate_instance_on_failure = true
}

resource "aws_route_table_association" "kinetic_workspaces" {
  subnet_id      = aws_subnet.kinetic_workspaces.id
  route_table_id = aws_vpc.kinetic_workspaces.default_route_table_id
}

# resource "aws_instance" "kinetic_workspaces" {
#   ami                  = data.aws_ami.kinetic_workspaces.id
#   instance_type        = "t3.micro"
#   key_name             = aws_key_pair.kinetic_workspaces.key_name
#   iam_instance_profile = aws_iam_instance_profile.ec2_kinetic_workspaces.name

#   subnet_id              = aws_subnet.kinetic_workspaces.id
#   vpc_security_group_ids = [aws_security_group.ec2_kinetic_workspaces.id]
# }


# output "workspaces_rstudio_ami_id" {
#   value = data.aws_ami.kinetic_workspaces.id
# }

output "ssh_key_name" {
  value = aws_key_pair.kinetic_workspaces.key_name
}

# resource "jwt_hashed_token" "authentication_hash" {
#   secret = "d4ec99b6843c41d6ab497c3898633a6d"
#   claims_json = "kinetic|Wed%2C%2001%20Mar%202023%2016%3A01%3A54%20GMT"
# }

# # kinetic|Wed%2C%2001%20Mar%202023%2016%3A01%3A54%20GMT|YOG3BqT9JTe7gd%2BDbnne5kPH3mNZh%2B2WTBUo%2FWmCc58%3D
# # kinetic|Sat, 24 Sep 2022 17:46:21 GMT|GrA/vSHTFZiXglz4rRuBvH7anv/iaI+GzswvCokHJJA=
# # |YOG3BqT9JTe7gd%2BDbnne5kPH3mNZh%2B2WTBUo%2FWmCc58%3D

# output "authentication_cookie" {
#   value = jwt_hashed_token.authentication_hash
# }
