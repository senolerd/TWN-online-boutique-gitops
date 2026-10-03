output "env" {
  value = var.environment
}

output "region" {
  value = var.region
}

output "vpc_id" {
  value = module.vpc.vpc_id
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

output "argocd-dir" {
  value = var.argocd-dir
}

