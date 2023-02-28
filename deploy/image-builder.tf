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
    component_arn = aws_imagebuilder_component.kinetic_workspaces.arn
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

resource "aws_imagebuilder_component" "kinetic_workspaces" {
  data = yamlencode({
    phases = [{
      name = "build"
      steps = [{
        action = "ExecuteBash"
        inputs = {
          commands = [
            "sudo wget -O /tmp/ssm.deb https://s3.${var.aws_region}.amazonaws.com/amazon-ssm-${var.aws_region}/latest/debian_amd64/amazon-ssm-agent.deb",
            "sudo dpkg -i /tmp/ssm.deb",
            "sudo apt-get update",
            "sudo apt-get install -y gnupg",
            "echo 'deb http://cloud.r-project.org/bin/linux/debian bullseye-cran40/' | sudo tee -a /etc/apt/sources.list.d/r.list > /dev/null",
            "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key '95C0FAF38DB3CCAD0C080A7BDC78B2DDEABC47B7'",
            "sudo apt-get update",
            "sudo apt-get install -y libatlas3-base r-base r-base-dev gdebi-core",
            "sudo wget -O /tmp/rstudio.deb  https://download2.rstudio.org/server/bionic/amd64/rstudio-server-2022.12.0-353-amd64.deb",
            "sudo apt-get -y upgrade",
            "sudo gdebi -n /tmp/rstudio.deb",
            "echo www-port=80 | sudo tee -a /etc/rstudio/rserver.conf > /dev/null",
            "adduser --disabled-password --shell /bin/false --gecos 'Kinetic Workspace' kinetic",
          ]
        }
        name      = "download_and_install_kinetic_workspaces"
        onFailure = "Abort"
      }]
    }]
    schemaVersion = 1.0
  })
  name     = "deploy_kinetic_workspaces"
  platform = "Linux"
  version  = "1.0.0"
}

resource "aws_imagebuilder_image" "kinetic_workspaces" {
  image_recipe_arn                 = aws_imagebuilder_image_recipe.kinetic_workspaces.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.kinetic_workspaces.arn
  enhanced_image_metadata_enabled  = true
}

resource "aws_imagebuilder_infrastructure_configuration" "kinetic_workspaces" {
  name                          = "kinetic_workspaces_infrastructure_configuration"
  description                   = "AWS image builder config for EC2 with Kinetic_Workspaces hosted"
  instance_profile_name         = aws_iam_instance_profile.ec2_kinetic_workspaces.name
  instance_types                = ["t3.micro"]
  security_group_ids            = [aws_security_group.ec2_kinetic_workspaces.id]
  subnet_id                     = aws_subnet.kinetic_workspaces.id
  terminate_instance_on_failure = true

}

resource "aws_route_table_association" "kinetic_workspaces" {
  subnet_id      = aws_subnet.kinetic_workspaces.id
  route_table_id = aws_route_table.kinetic_workspaces.id
}

resource "aws_instance" "kinetic_workspaces" {
  ami                  = data.aws_ami.kinetic_workspaces.id
  instance_type        = "t3.micro"
  key_name             = aws_key_pair.kinetic_workspaces.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_kinetic_workspaces.name

  subnet_id              = aws_subnet.kinetic_workspaces.id
  vpc_security_group_ids = [aws_security_group.ec2_kinetic_workspaces.id]
}




output "workspaces_rstudio_ami_id" {
  value = data.aws_ami.kinetic_workspaces.id
}

output "ssh_key_name" {
  value = aws_key_pair.kinetic_workspaces.key_name
}

