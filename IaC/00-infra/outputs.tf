output "Environment" {
  value = "${var.environment}"
}

output "eks_cluster_name" {
  value = module.eks.eks_cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.eks_cluster_endpoint
}

output "eks_cluster_ca_data" {
  value = module.eks.eks_cluster_ca_data
}

output "eks_cluster_region" {
  value = module.eks.eks_cluster_region
}


