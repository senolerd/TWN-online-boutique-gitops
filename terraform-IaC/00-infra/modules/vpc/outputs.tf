output "vpc_id" {
  description = "VPC ID"
  value = aws_vpc.project_vpc.id
}

output "vpc_name" {
  description = "VPC NAME"
  value = "${var.project_name}-${var.environment}"
}

output "private_subnets" {
  value = local.private_subnets
}
