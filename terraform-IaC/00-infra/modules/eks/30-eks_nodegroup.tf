resource "aws_eks_node_group" "ng1" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "ng-${aws_eks_cluster.eks.name}"
  node_role_arn   = aws_iam_role.role_for_nodegroup.arn
  subnet_ids      = [for subnet in var.private_subnets : subnet.id]
  instance_types  = var.environment == "dev" ? var.instance_types.dev : var.instance_types.prod

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }
  region = var.region
  
  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_eks_addon.kube-proxy,
    aws_eks_addon.vpc-cni,
    aws_iam_role_policy_attachment.ng-role-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.ng-role-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.ng-role-AmazonEC2ContainerRegistryReadOnly,
    aws_eks_access_entry.eks_access_entry_for_whoami
  ]
  tags = { 
    "managedBy" : "terraform"
    "env": var.environment
  }
}

resource "aws_iam_role" "role_for_nodegroup" {
  name = "eks-nodegroup-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "ng-role-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.role_for_nodegroup.name
}

resource "aws_iam_role_policy_attachment" "ng-role-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.role_for_nodegroup.name
}

resource "aws_iam_role_policy_attachment" "ng-role-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.role_for_nodegroup.name
}



###############################################################################################

# This IAM user (the IAM account used by Terraform now) access entry for EKS cluster
  # EKS access entry and its role for the user whose access key is used for this Terraform config.
  # Without this, EKS console looks so messy because this user doesn't have access to see
  # whats going in that EKS cluster. 
data "aws_caller_identity" "whoami" {}

resource "aws_eks_access_entry" "eks_access_entry_for_whoami" {
  cluster_name  = aws_eks_cluster.eks.name
  principal_arn = data.aws_caller_identity.whoami.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "eks_access_policy_association_to_whoami" {
  depends_on = [ aws_eks_access_entry.eks_access_entry_for_whoami ]
  cluster_name  = aws_eks_cluster.eks.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = data.aws_caller_identity.whoami.arn
  access_scope {
    type = "cluster"
  }
}

###############################################################################################