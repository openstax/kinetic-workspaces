
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
      Application = "KineticWorkspaces"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
