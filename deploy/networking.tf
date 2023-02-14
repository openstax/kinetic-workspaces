resource "aws_vpc" "kinetic_workspaces_builder" {
 cidr_block = "10.0.0.0/16"

 tags = {
    Name = "KineticWorkspacesVPC"
 }
}

resource "aws_subnet" "kinetic_workspaces_builder" {
  vpc_id                  = aws_vpc.kinetic_workspaces_builder.id
  cidr_block              = var.builderCIDRblock
  map_public_ip_on_launch = var.mapPublicIP
  availability_zone       = var.availabilityZone
  tags = {
    Name = "KineticWorkspacesSubnet"
  }
}


resource "aws_eip" "kinetic_workspaces_builder" {
  instance = aws_instance.kinetic_workspaces_builder.id
  vpc = true
  tags = {
    Name        = "kineticWorkspacesBuilderEIP"
    Project     = "Research"
    Application = "Kinetic"
  }
}

resource "aws_internet_gateway" "kinetic_workspaces_builder" {
  vpc_id   = aws_vpc.kinetic_workspaces_builder.id
  tags = {
    Name        = "kineticWorkspacesBuilderGW"
  }
}

resource "aws_route_table" "kinetic_workspaces_builder" {
  vpc_id = aws_vpc.kinetic_workspaces_builder.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kinetic_workspaces_builder.id
  }
  tags = {
    Name        = "kineticBuilderRouteTable"
  }
}


# Standard route53 DNS record for "myapp" pointing to an ALB
# resource "aws_route53_record" "kinetic_workspaces" {
#   zone_id = data.aws_route53_zone.kinetic_workspaces.zone_id
#   name    = "${var.subDomainName}.${data.aws_route53_zone.kinetic_workspaces.name}"
#   type    = "A"
# alias {
#     name                   = aws_alb.mylb.dns_name
#     zone_id                = aws_alb.mylb.zone_id
#     evaluate_target_health = false
#   }
#   provider = aws.account_route53
# }
