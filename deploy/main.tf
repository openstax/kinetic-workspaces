
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
  backend "s3" {
  }
}

data "aws_ecr_authorization_token" "token" {}

provider "docker" {
  host = "unix:///var/run/docker.sock"
  registry_auth {
    address  = split("/", aws_ecr_repository.kinetic_workspaces.repository_url)[0]
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}


provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Name        = "Kinetic Workspaces"
      Environment = var.environment_name
      Project     = "Research"
      Application = "KineticWorkspaces"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

locals {
  domain_name       = "${var.sub_domain_name}.${var.base_domain_name}"
  mime_types        = jsondecode(file("${path.module}/mime.json"))
  env_dash          = var.environment_name == "production" ? "" : "-${var.environment_name}"
  env_underscore    = var.environment_name == "production" ? "" : "_${var.environment_name}"
  front_desk_sha    = sha1(join("", [for f in fileset("${path.module}/../front-desk/editor", "*") : filesha1("${path.module}/../front-desk/editor/${f}")]))
  lambda_source_sha = sha1(join("", [for f in fileset("${path.module}/../front-desk/server", "*") : filesha1("${path.module}/../front-desk/server/${f}")]))
}
