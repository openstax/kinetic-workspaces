resource "aws_efs_file_system" "kinetic_workspaces" {
  availability_zone_name = var.availabilityZone

  lifecycle_policy {
    transition_to_ia = "AFTER_14_DAYS"
  }

  tags = {
    Name = "kinetic${local.env_dash}-workspaces"
  }
}

resource "aws_efs_mount_target" "kinetic_workspaces" {

  file_system_id  = aws_efs_file_system.kinetic_workspaces.id
  subnet_id       = aws_subnet.kinetic_workspaces.id
  security_groups = [aws_security_group.kinetic_workspaces.id]
}

resource "aws_efs_access_point" "kinetic_workspaces" {
  file_system_id = aws_efs_file_system.kinetic_workspaces.id
  posix_user {
    gid = 0
    uid = 0
  }
}
