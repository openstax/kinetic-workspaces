resource "aws_vpc" "kinetic_workspaces" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "KineticWorkspaces"
  }
}

resource "aws_subnet" "kinetic_workspaces" {
  vpc_id                  = aws_vpc.kinetic_workspaces.id
  cidr_block              = aws_vpc.kinetic_workspaces.cidr_block
  map_public_ip_on_launch = var.mapPublicIP
  availability_zone       = var.availabilityZone
  tags = {
    Name = "KineticWorkspaces"
  }
}


# resource "aws_eip" "kinetic_workspaces" {
#   instance = aws_instance.kinetic_workspaces.id
#   vpc = true
#   tags = {
#     Name        = "kineticWorkspaces"
#   }
# }

resource "aws_internet_gateway" "kinetic_workspaces" {
  vpc_id = aws_vpc.kinetic_workspaces.id
  tags = {
    Name = "kineticWorkspaces"
  }
}

resource "aws_route_table" "kinetic_workspaces" {
  vpc_id = aws_vpc.kinetic_workspaces.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kinetic_workspaces.id
  }
  tags = {
    Name = "kineticRouteTable"
  }
}

output "workspaces_vpc_id" {
  value = aws_vpc.kinetic_workspaces.id
}

output "workspaces_subnet_id" {
  value = aws_subnet.kinetic_workspaces.id
}


