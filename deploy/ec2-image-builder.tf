resource "tls_private_key" "kinetic_workspaces" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kinetic_workspaces" {
  key_name   = "KineticWorkspaces"
  public_key = tls_private_key.kinetic_workspaces.public_key_openssh
}


data "aws_ami" "kinetic_workspaces" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [aws_imagebuilder_image.kinetic_workspaces.name, "${aws_imagebuilder_image.kinetic_workspaces.name}*"]
  }
}

data "aws_ami" "kinetic_workspaces_parent_image" {
  most_recent = true
  owners      = ["136693071363"]
  filter {
    name   = "name"
    values = ["debian-11-amd64-*"]
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

resource "aws_imagebuilder_image_pipeline" "kinetic_workspaces" {
  name             = "kinetic_workspaces_image_pipeline"
  image_recipe_arn = aws_imagebuilder_image_recipe.kinetic_workspaces.arn

  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.kinetic_workspaces.arn
}


resource "aws_imagebuilder_image_recipe" "kinetic_workspaces" {
  component {
    component_arn = aws_imagebuilder_component.kinetic_workspaces_config_files.arn
  }

  component {
    component_arn = "arn:aws:imagebuilder:${var.aws_region}:aws:component/update-linux/x.x.x"
  }


  component {
    component_arn = aws_imagebuilder_component.kinetic_workspaces_install_r_and_pkgs.arn
  }

  component {
    component_arn = aws_imagebuilder_component.ec2_kinetic_workspaces.arn
  }


  name         = "kinetic_workspaces_image"
  parent_image = data.aws_ami.kinetic_workspaces_parent_image.id
  version      = "1.0.0"
}

resource "aws_imagebuilder_distribution_configuration" "kinetic_workspaces" {
  name = "kinetic_workspaces_distribution_configuration"

  distribution {
    ami_distribution_configuration {
      name = "kinetic_workspaces-{{ imagebuilder:buildDate }}"
    }

    region = var.aws_region
  }
}


resource "aws_imagebuilder_image" "kinetic_workspaces" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.kinetic_workspaces.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.kinetic_workspaces.arn
  enhanced_image_metadata_enabled  = true
}

# this does not force replacement when the file changes, it only tells terraform to wait
# until their uploaded before running this step. To force regeneration run:
# terraform apply -replace=aws_imagebuilder_infrastructure_configuration.kinetic_workspaces
resource "aws_imagebuilder_infrastructure_configuration" "kinetic_workspaces" {
  name                          = "kinetic_workspaces_infrastructure_configuration"
  description                   = "AWS image builder config for EC2 with Kinetic_Workspaces hosted"
  instance_profile_name         = aws_iam_instance_profile.ec2_kinetic_workspaces.name
  instance_types                = ["t3.large"] # using a 2xlarge to speed up builds
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


output "workspaces_rstudio_ami_id" {
  value = data.aws_ami.kinetic_workspaces.id
}

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
