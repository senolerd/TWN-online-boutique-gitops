output "vpc_id" {
  description = "VPC ID"
  value = aws_vpc.project_vpc.id
}

output "private_subnets" {
  value = local.private_subnets
}

output "vpc_endpoint_sg_for_eks_id" {
  # If environment is dev, EKS controllers SG will be added to this Endpoints SG as reference SG after the EKS 
  # controllers are created. 
  value = var.environment == "dev" ? aws_security_group.vpc-endpoint-sg-for-eks[0].id: null
}