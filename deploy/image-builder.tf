data "aws_key_pair" "nathan" {
  key_name          = "nathan"
  include_public_key = true
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
  most_recent      = true
  owners = ["136693071363"]
  filter {
    name   = "name"
    values = ["debian-11-amd64-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
}

data "aws_partition" "current" {}

resource "aws_imagebuilder_image_pipeline" "kinetic_workspaces" {
  name                             = "kinetic_workspaces_image_pipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.kinetic_workspaces.arn

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
  enhanced_image_metadata_enabled  = false
}

resource "aws_imagebuilder_infrastructure_configuration" "kinetic_workspaces" {
  name                          = "kinetic_workspaces_infrastructure_configuration"
  description                   = "AWS image builder config for EC2 with Kinetic_Workspaces hosted"
  instance_profile_name         = aws_iam_instance_profile.ec2_kinetic_workspaces.name
  instance_types                = ["t3.micro"]
  security_group_ids            = [aws_security_group.ec2_kinetic_workspaces_builder.id]
  subnet_id                     = aws_subnet.kinetic_workspaces_builder.id
  terminate_instance_on_failure = true

}

resource "aws_route_table_association" "kinetic_workspaces_builder" {
  subnet_id      = aws_subnet.kinetic_workspaces_builder.id
  route_table_id = aws_route_table.kinetic_workspaces_builder.id
}

resource "aws_instance" "kinetic_workspaces_builder" {
  ami                  = data.aws_ami.kinetic_workspaces.id
  instance_type        = "t3.micro"
  key_name             = data.aws_key_pair.nathan.key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_kinetic_workspaces.name
  security_groups      = [aws_security_group.ec2_kinetic_workspaces_builder.id]
  subnet_id            = aws_subnet.kinetic_workspaces_builder.id
}

resource "aws_security_group" "ec2_kinetic_workspaces_builder" {
  description = "Controls access to EC2 Image Builder with Kinetic_Workspaces"

  vpc_id = aws_vpc.kinetic_workspaces_builder.id
  name   = "ec2-image-builder-sg"

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
}

    # {
    #   "Effect": "Allow",
    #   "Action": "s3:ListAllMyBuckets",
    #   "Resource": "*"
    # },

resource "aws_iam_role_policy" "ec2_kinetic_workspaces" {
  name_prefix = "ec2-kinetic_workspaces-role-policy-"
  role        = aws_iam_role.ec2_kinetic_workspaces.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketACL",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::${aws_s3_bucket.kinetic_workspaces_conf_files.bucket}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListMultipartUploadParts",
        "s3:AbortMultipartUpload"
      ],
      "Resource": "arn:aws:s3:::${aws_s3_bucket.kinetic_workspaces_conf_files.bucket}/*"
    }
  ]
}
EOF
}

resource "aws_iam_role" "ec2_kinetic_workspaces" {
  name_prefix = "ec2-kinetic_workspaces-role-"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "ec2.amazonaws.com",
          "imagebuilder.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2_kinetic_workspaces" {
  name_prefix = "ec2-kinetic-workspaces-instance-profile-"
  role        = aws_iam_role.ec2_kinetic_workspaces.name
}

resource "aws_iam_role_policy_attachment" "role-policy-attachment" {
  for_each = toset([
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])

  role       = aws_iam_role.ec2_kinetic_workspaces.name
  policy_arn = each.value
}
