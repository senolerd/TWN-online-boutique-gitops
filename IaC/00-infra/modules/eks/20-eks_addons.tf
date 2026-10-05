# Full addon list for default console EKS install
# - Amazon EKS Pod Identity Agent
# - Amazon VPC CNI (role needed)
# - kube-proxy 
# - CoreDNS 

# - External DNS (role needed)
# - Node monitoring agent
# - Metrics Server



##############################################################

# EKS Pod Identity Trust Policy
data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

##############################################################

###### Pod Identity agent addon (Default for installing with EKS console normal mode)
resource "aws_eks_addon" "eks-pod-identity-agent" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "eks-pod-identity-agent"
  addon_version = "v1.3.10-eksbuild.3"
  resolve_conflicts_on_update = "PRESERVE"
}


###### Amazon VPC CNI (Default for installing with EKS console normal mode)

resource "aws_iam_role" "vpc-cni-pod-identity-role" {
  name = "pod-identity-role-for-${aws_eks_cluster.eks.name}-vpc-cni"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  # assume_role_policy = jsonencode({
  #   "Version" : "2012-10-17",
  #   "Statement" : [
  #     {
  #       "Effect" : "Allow",
  #       "Principal" : {
  #         "Service" : "pods.eks.amazonaws.com"
  #       },
  #       "Action" : [
  #         "sts:AssumeRole",
  #         "sts:TagSession"
  #       ]
  #     }
  #   ]
  # })
}

resource "aws_iam_role_policy_attachment" "vpc-cni-role-policy-attachment" {
  role       = aws_iam_role.vpc-cni-pod-identity-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy" # it is aws managed
}


resource "aws_eks_addon" "vpc-cni" {
  depends_on = [ aws_eks_addon.eks-pod-identity-agent, aws_iam_role_policy_attachment.vpc-cni-role-policy-attachment ]
  cluster_name                = aws_eks_cluster.eks.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.22.3-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  pod_identity_association {
    role_arn = aws_iam_role.vpc-cni-pod-identity-role.arn
    service_account = "aws-node"
  }
  namespace_config {
    namespace = "kube-system"
  }
}

###### ExternalDNS - watches gateway and ingress objects if there there is any hostname is defined

# 1. Route53 Permissions Policy
resource "aws_iam_policy" "external-dns-policy" {
  name        = "ExternalDNSGatewayAPIPolicy"
  description = "ExternalDNS access to Route53 records"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets"]
        Resource = ["arn:aws:route53:::hostedzone/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListTagsForResources"
        ]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role" "external-dns-role" {
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  name = "pod-identity-role-for-${aws_eks_cluster.eks.name}-external-dns"
}

resource "aws_iam_role_policy_attachment" "name" {
  policy_arn = aws_iam_policy.external-dns-policy.arn
  role = aws_iam_role.external-dns-role.name
}

resource "aws_eks_addon" "external-dns" {
  cluster_name                = aws_eks_cluster.eks.name
  addon_name                  = "external-dns"
  addon_version               = "v0.23.0-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  pod_identity_association {
    role_arn = aws_iam_role.external-dns-role.arn
    service_account = "external-dns"
  }
  namespace_config { namespace = "external-dns" }
}






###### kube-proxy (Default for installing with EKS console normal mode)
resource "aws_eks_addon" "kube-proxy" {
  depends_on = [ aws_eks_cluster.eks ]
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "kube-proxy"
  addon_version = "v1.36.0-eksbuild.13"
  resolve_conflicts_on_update = "PRESERVE"
}


###### coredns (Default for installing with EKS console normal mode)
resource "aws_eks_addon" "coredns" {
  depends_on = [ aws_eks_node_group.ng1 ]
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "coredns"
  addon_version = "v1.14.3-eksbuild.3"
  resolve_conflicts_on_update = "PRESERVE"
}


