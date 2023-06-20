resource "random_id" "rstudio_cookie_key" {
  byte_length = 16
}


resource "aws_security_group" "kinetic_workspaces" {
  description = "Controls access to EC2 Image Builder with Kinetic_Workspaces"

  vpc_id = aws_vpc.kinetic_workspaces.id
  name   = "kinetic-workspaces"

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

resource "aws_iam_role" "kinetic_workspaces_image_builder" {
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


resource "aws_iam_role_policy" "kinetic_workspaces_image_builder" {
  name_prefix = "kinetic_workspaces-image-builder-policy-"
  role        = aws_iam_role.kinetic_workspaces_image_builder.name

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
      # {
      #   Effect = "Allow",
      #   Action = [
      #     "s3:GetObject",
      #     "s3:PutObject",
      #     "s3:ListMultipartUploadParts",
      #     "s3:AbortMultipartUpload",
      #   ],
      #   Resource = "arn:aws:s3:::${aws_s3_bucket.kinetic_workspaces_conf_files.bucket}/*"
      # },
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

resource "aws_iam_role" "kinetic_workspaces_enclave" {
  name = "kinetic_workspaces_enclave"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "kinetic_workspaces_enclave" {
  name = "kinetic_workspaces_enclave"
  role = aws_iam_role.kinetic_workspaces_enclave.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "APIAccessForDynamoDBStreams"
        Effect   = "Allow",
        Resource = aws_dynamodb_table.kinetic_ws_front_desk.arn,
        Action = [
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchWriteItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
        ],
      },
      # {
      #   Effect = "Allow",
      #   Action = [
      #     "ecr:CompleteLayerUpload",
      #     "ecr:GetDownloadUrlForLayer",
      #     "ecr:GetAuthorizationToken",
      #     "ecr:UploadLayerPart",

      #     "ecr:BatchGetImage",
      #     "ecr:BatchCheckLayerAvailability",
      #     "ecr:PutImage"
      #   ],
      #   Resource = "${aws_ecr_repository.kinetic_workspaces.arn}/*"
      # },
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ],
        Resource = aws_ecr_repository.kinetic_workspaces.arn
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:PutObject",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ],
        Resource = "${aws_s3_bucket.kinetic_workspaces_archives.arn}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = "${aws_s3_bucket.kinetic_workspaces_conf_files.arn}/*"
      },
      {
        Effect = "Allow",
        Action = [
          "states:SendTaskSuccess",
          "states:SendTaskFailure",
        ],
        Resource = "*"
      },

    ]
  })
}

resource "aws_iam_instance_profile" "kinetic_workspaces_enclave" {
  name_prefix = "kinetic-workspaces-enclave-profile-"
  role        = aws_iam_role.kinetic_workspaces_enclave.name
}



resource "aws_iam_instance_profile" "kinetic_workspaces_image_builder" {
  name_prefix = "kinetic-workspaces-image-builder-profile-"
  role        = aws_iam_role.kinetic_workspaces_image_builder.name
}

resource "aws_iam_role_policy_attachment" "role-policy-attachment" {
  for_each = toset([
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])

  role       = aws_iam_role.kinetic_workspaces_image_builder.name
  policy_arn = each.value
}


output "editor_ami_id" {
  value = data.aws_ami.kinetic_workspaces_editor.id
}


output "workspaces_security_group_id" {
  value = aws_security_group.kinetic_workspaces.id
}

output "workspaces_ssh_key_pem" {
  value     = tls_private_key.kinetic_workspaces.private_key_openssh
  sensitive = true
}
