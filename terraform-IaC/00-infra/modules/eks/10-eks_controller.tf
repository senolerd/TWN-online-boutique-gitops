
resource "aws_eks_cluster" "eks" {
  name = "${var.project_name}-${var.environment}"
  role_arn = aws_iam_role.cluster_role.arn
  version  = "1.36"

  access_config {
    authentication_mode = "API"
  }

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    subnet_ids              = [for subnet in var.private_subnets : subnet.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
  ]
  tags = { 
    "managedBy" : "terraform"
    "env": var.environment
    "domain" = var.hosted_zone_name
  }  
}

###############################################################################################
resource "aws_iam_role" "cluster_role" {
  # Creating a role and associate policy for K8s service that can work on AWS.
  name = "eks-cluster-role-for-${var.project_name}-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster_role.name
}
