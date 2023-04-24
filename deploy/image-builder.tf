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
  name     = "deploy_kinetic_workspaces"
  platform = "Linux"
  version  = "1.0.0"

  # this does not force replacement when the file changes, it only tells terraform to wait
  # until their uploaded before running this step. To force regeneration run:
  # terraform apply -replace=aws_imagebuilder_component.kinetic_workspaces
  depends_on = [
    aws_s3_object.kinetic_workspaces_conf_files["nginx-proxy.conf"],
    aws_s3_object.kinetic_workspaces_conf_files["provision-letsencrypt"],
  ]

  # ExecuteBash https://docs.aws.amazon.com/imagebuilder/latest/userguide/toe-action-modules.html#action-modules-executebash
  data = yamlencode({
    phases = [{
      name = "build"
      steps = [{
        action = "ExecuteBash"
        inputs = {
          commands = [
            "export DEBIAN_FRONTEND=noninteractive",
            "sudo apt-get update",
            "sudo apt-get install -y git build-essential binutils nginx-light certbot python3-certbot-dns-route53 ruby-aws-sdk-s3",
            "sudo wget --no-verbose -O /tmp/ssm.deb https://s3.${var.aws_region}.amazonaws.com/amazon-ssm-${var.aws_region}/latest/debian_amd64/amazon-ssm-agent.deb",
            "sudo dpkg -i /tmp/ssm.deb",
            "cd /tmp && git clone https://github.com/aws/efs-utils",
            "cd /tmp/efs-utils && ./build-deb.sh && sudo apt-get -y install ./build/amazon-efs-utils*deb",
            "aws s3 cp s3://${aws_s3_bucket.kinetic_workspaces_conf_files.id}/configs/install_r_and_pkgs /tmp/",
            "sudo bash /tmp/install_r_and_pkgs ${aws_s3_bucket.kinetic_workspaces_conf_files.id} ${local.domain_name}",
            "echo ${random_id.rstudio_cookie_key.hex} > /var/lib/rstudio-server/secure-cookie-key",
            "aws s3 cp s3://${aws_s3_bucket.kinetic_workspaces_conf_files.id}/configs/provision-letsencrypt /tmp/",
            "ruby /tmp/provision-letsencrypt ${local.domain_name} ${aws_s3_bucket.kinetic_workspaces_conf_files.id}",
            "sudo aws s3 cp s3://${aws_s3_bucket.kinetic_workspaces_conf_files.id}/configs/nginx-proxy.conf /etc/nginx/sites-enabled/default",
            "sudo sudo apt-get clean",
          ]
        }
        name      = "download_and_install_kinetic_workspaces"
        onFailure = "Abort"
      }]
    }]
    schemaVersion = 1.0
  })
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
  instance_types                = ["t3.2xlarge"] # using a 2xlarge to speed up builds
  security_group_ids            = [aws_security_group.ec2_kinetic_workspaces.id]
  subnet_id                     = aws_subnet.kinetic_workspaces.id
  terminate_instance_on_failure = true

}

resource "aws_route_table_association" "kinetic_workspaces" {
  subnet_id      = aws_subnet.kinetic_workspaces.id
  route_table_id = aws_route_table.kinetic_workspaces.id
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
