resource "random_id" "rstudio_cookie_key" {
  byte_length = 16
}


resource "aws_security_group" "ec2_kinetic_workspaces" {
  description = "Controls access to EC2 Image Builder with Kinetic_Workspaces"

  vpc_id = aws_vpc.kinetic_workspaces.id
  name   = "kinetic-workspaces-ec2"

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
    to_port   = 22
    protocol  = "tcp"
  }
}

resource "aws_iam_role" "ec2_kinetic_workspaces" {
  name_prefix = "ec2-kinetic_workspaces-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow",
      Sid    = "",
      Principal = {
        Service = [
          "ec2.amazonaws.com",
          "imagebuilder.amazonaws.com"
        ]
      }
    }]
  })
}


resource "aws_iam_role_policy" "ec2_kinetic_workspaces" {
  name_prefix = "ec2-kinetic_workspaces-role-policy-"
  role        = aws_iam_role.ec2_kinetic_workspaces.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:ListBucket",
          "s3:GetBucketACL",
          "s3:GetBucketLocation"
        ],
        Resource = "arn:aws:s3:::${aws_s3_bucket.kinetic_workspaces_conf_files.bucket}"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload",
        ],
        Resource = "arn:aws:s3:::${aws_s3_bucket.kinetic_workspaces_conf_files.bucket}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "route53:ChangeResourceRecordSets"
        ],
        Resource = "arn:aws:route53:::hostedzone/${aws_route53_zone.kinetic_workspaces.id}"
      },
      {
        Effect = "Allow",
        Action = [
          "route53:GetChange",
          "route53:ListHostedZones",
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientRootAccess",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:DescribeMountTargets",
        ],
        Resource = "*"
      }
    ]
  })
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


output "editor_ami_id" {
  value = data.aws_ami.kinetic_workspaces.id
}


output "workspaces_security_group_id" {
  value = aws_security_group.ec2_kinetic_workspaces.id
}

output "workspaces_ssh_key_pem" {
  value     = tls_private_key.kinetic_workspaces.private_key_openssh
  sensitive = true
}
