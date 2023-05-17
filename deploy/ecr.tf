
resource "aws_ecr_repository" "kinetic_workspaces" {
  name = "kinetic_workspaces"
}

output "workspaces_ecr_repository_url" {
  value = aws_ecr_repository.kinetic_workspaces.repository_url
}
