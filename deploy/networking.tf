resource "aws_vpc" "kinetic_workspaces" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "kinetic-${var.environment_name}-workspaces"
  }
}

resource "aws_subnet" "kinetic_workspaces" {
  vpc_id                  = aws_vpc.kinetic_workspaces.id
  cidr_block              = aws_vpc.kinetic_workspaces.cidr_block
  map_public_ip_on_launch = var.mapPublicIP
  availability_zone       = var.availabilityZone
  tags = {
    Name = "kinetic-${var.environment_name}-workspaces"
  }
}

resource "aws_route_table" "kinetic_workspaces" {
  vpc_id = aws_vpc.kinetic_workspaces.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kinetic_workspaces.id
    # gateway_id = aws_nat_gateway.kinetic_workspaces.id
  }
  tags = {
    Name = "kinetic-${var.environment_name}-workspaces"
  }
}

resource "aws_internet_gateway" "kinetic_workspaces" {
  vpc_id = aws_vpc.kinetic_workspaces.id
  tags = {
    Name = "kinetic-${var.environment_name}-workspaces"
  }
}



resource "aws_vpc_endpoint" "kinetic_workspaces_ssm" {
  vpc_id            = aws_vpc.kinetic_workspaces.id
  service_name      = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type = "Interface"
}
resource "aws_vpc_endpoint" "kinetic_workspaces_ec2messages" {
  vpc_id            = aws_vpc.kinetic_workspaces.id
  service_name      = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type = "Interface"
}
resource "aws_vpc_endpoint" "kinetic_workspaces_ssmmessages" {
  vpc_id            = aws_vpc.kinetic_workspaces.id
  service_name      = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type = "Interface"
}
resource "aws_vpc_endpoint" "kinetic_workspaces_logs" {
  vpc_id            = aws_vpc.kinetic_workspaces.id
  service_name      = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type = "Interface"
}
resource "aws_vpc_endpoint" "kinetic_workspaces_s3" {
  vpc_id            = aws_vpc.kinetic_workspaces.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
}
resource "aws_vpc_endpoint" "kinetic_workspaces_ec2" {
  vpc_id            = aws_vpc.kinetic_workspaces.id
  service_name      = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type = "Interface"

  security_group_ids  = [aws_security_group.kinetic_workspaces.id]
  subnet_ids          = [aws_subnet.kinetic_workspaces.id]
  private_dns_enabled = true
}

# resource "aws_eip" "kinetic_workspaces" {
#   vpc = true
# }

# resource "aws_nat_gateway" "kinetic_workspaces" {
#   allocation_id = aws_eip.kinetic_workspaces.id
#   subnet_id     = aws_subnet.kinetic_workspaces.id
#   tags = {
#     "Name" = "KineticWorkspacesNatGW"
#   }
# }
