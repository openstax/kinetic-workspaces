
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
  }
}


provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Name        = "Kinetic Workspaces"
      Environment = "All"
      Project     = "Research"
      Application = "Kinetic"
    }
  }
}
