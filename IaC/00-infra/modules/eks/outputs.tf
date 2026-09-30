output "eks_cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

output "eks_cluster_ca_data" {
  value = aws_eks_cluster.eks.certificate_authority[0].data
}

output "eks_cluster_region" {
  value = aws_eks_cluster.eks.region
}



# data "aws_eks_cluster_auth" "this" {
#   depends_on = [aws_eks_cluster.eks]
#   name = aws_eks_cluster.eks.name
# }

# data "aws_eks_cluster" "this" {
#   name = aws_eks_cluster.eks.name
# }

# ############################################# 
# output "cluster" {
#   value = data.aws_eks_cluster.this
# }

# output "cluster_auth" {
#   value = data.aws_eks_cluster_auth.this
# }


# output "nodegroup" {
#   value = aws_eks_node_group.ng1
# }