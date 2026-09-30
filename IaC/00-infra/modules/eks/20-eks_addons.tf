# Full addon list for default console EKS install
# - Amazon EKS Pod Identity Agent
# - Amazon VPC CNI (role needed)
# - kube-proxy 
# - CoreDNS 

# - External DNS (role needed)
# - Node monitoring agent
# - Metrics Server


###### Pod Identity agent addon (Default for installing with EKS console normal mode)
resource "aws_eks_addon" "eks-pod-identity-agent" {
  cluster_name = aws_eks_cluster.eks.name
  addon_name   = "eks-pod-identity-agent"
  addon_version = "v1.3.10-eksbuild.3"
  resolve_conflicts_on_update = "PRESERVE"
}

###### Amazon VPC CNI (Default for installing with EKS console normal mode)
resource "aws_eks_addon" "vpc-cni" {
  depends_on = [ aws_eks_addon.eks-pod-identity-agent ]
  cluster_name                = aws_eks_cluster.eks.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.22.3-eksbuild.1"
  resolve_conflicts_on_update = "PRESERVE"
  pod_identity_association {
    role_arn = aws_iam_role.role-for-pods.arn
    service_account = "aws-node"
  }
  namespace_config {
    namespace = "kube-system"
  }
}

resource "aws_iam_role" "role-for-pods" {
  name = "pod-identity-role-for-${aws_eks_cluster.eks.name}-vpc-cni"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "pods.eks.amazonaws.com"
        },
        "Action" : [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "pod-role-policy-attachment" {
  role       = aws_iam_role.role-for-pods.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
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










# resource "aws_iam_policy" "aws_lb_controller" {
#   name        = "aws_lb_controller"
#   path        = "/"
#   description = "IAM policy for AWS LoadBalancerController"
#   policy = jsonencode({
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "iam:CreateServiceLinkedRole"
#             ],
#             "Resource": "*",
#             "Condition": {
#                 "StringEquals": {
#                     "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
#                 }
#             }
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "ec2:DescribeAccountAttributes",
#                 "ec2:DescribeAddresses",
#                 "ec2:DescribeAvailabilityZones",
#                 "ec2:DescribeInternetGateways",
#                 "ec2:DescribeVpcs",
#                 "ec2:DescribeVpcPeeringConnections",
#                 "ec2:DescribeSubnets",
#                 "ec2:DescribeSecurityGroups",
#                 "ec2:DescribeInstances",
#                 "ec2:DescribeNetworkInterfaces",
#                 "ec2:DescribeTags",
#                 "ec2:GetCoipPoolUsage",
#                 "ec2:DescribeCoipPools",
#                 "ec2:GetSecurityGroupsForVpc",
#                 "ec2:DescribeIpamPools",
#                 "ec2:DescribeRouteTables",
#                 "elasticloadbalancing:DescribeLoadBalancers",
#                 "elasticloadbalancing:DescribeLoadBalancerAttributes",
#                 "elasticloadbalancing:DescribeListeners",
#                 "elasticloadbalancing:DescribeListenerCertificates",
#                 "elasticloadbalancing:DescribeSSLPolicies",
#                 "elasticloadbalancing:DescribeRules",
#                 "elasticloadbalancing:DescribeTargetGroups",
#                 "elasticloadbalancing:DescribeTargetGroupAttributes",
#                 "elasticloadbalancing:DescribeTargetHealth",
#                 "elasticloadbalancing:DescribeTags",
#                 "elasticloadbalancing:DescribeTrustStores",
#                 "elasticloadbalancing:DescribeListenerAttributes",
#                 "elasticloadbalancing:DescribeCapacityReservation"
#             ],
#             "Resource": "*"
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "cognito-idp:DescribeUserPoolClient",
#                 "acm:ListCertificates",
#                 "acm:DescribeCertificate",
#                 "iam:ListServerCertificates",
#                 "iam:GetServerCertificate",
#                 "waf-regional:GetWebACL",
#                 "waf-regional:GetWebACLForResource",
#                 "waf-regional:AssociateWebACL",
#                 "waf-regional:DisassociateWebACL",
#                 "wafv2:GetWebACL",
#                 "wafv2:GetWebACLForResource",
#                 "wafv2:AssociateWebACL",
#                 "wafv2:DisassociateWebACL",
#                 "shield:GetSubscriptionState",
#                 "shield:DescribeProtection",
#                 "shield:CreateProtection",
#                 "shield:DeleteProtection"
#             ],
#             "Resource": "*"
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "ec2:AuthorizeSecurityGroupIngress",
#                 "ec2:RevokeSecurityGroupIngress"
#             ],
#             "Resource": "*"
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "ec2:CreateSecurityGroup"
#             ],
#             "Resource": "*"
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "ec2:CreateTags"
#             ],
#             "Resource": "arn:aws:ec2:*:*:security-group/*",
#             "Condition": {
#                 "StringEquals": {
#                     "ec2:CreateAction": "CreateSecurityGroup"
#                 },
#                 "Null": {
#                     "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
#                 }
#             }
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "ec2:CreateTags",
#                 "ec2:DeleteTags"
#             ],
#             "Resource": "arn:aws:ec2:*:*:security-group/*",
#             "Condition": {
#                 "Null": {
#                     "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
#                     "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
#                 }
#             }
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "ec2:AuthorizeSecurityGroupIngress",
#                 "ec2:RevokeSecurityGroupIngress",
#                 "ec2:DeleteSecurityGroup"
#             ],
#             "Resource": "*",
#             "Condition": {
#                 "Null": {
#                     "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
#                 }
#             }
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "elasticloadbalancing:CreateLoadBalancer",
#                 "elasticloadbalancing:CreateTargetGroup"
#             ],
#             "Resource": "*",
#             "Condition": {
#                 "Null": {
#                     "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
#                 }
#             }
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "elasticloadbalancing:CreateListener",
#                 "elasticloadbalancing:DeleteListener",
#                 "elasticloadbalancing:CreateRule",
#                 "elasticloadbalancing:DeleteRule"
#             ],
#             "Resource": "*"
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "elasticloadbalancing:AddTags",
#                 "elasticloadbalancing:RemoveTags"
#             ],
#             "Resource": [
#                 "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
#                 "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
#                 "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
#             ],
#             "Condition": {
#                 "Null": {
#                     "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
#                     "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
#                 }
#             }
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "elasticloadbalancing:AddTags",
#                 "elasticloadbalancing:RemoveTags"
#             ],
#             "Resource": [
#                 "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
#                 "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
#                 "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
#                 "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
#             ]
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "elasticloadbalancing:ModifyLoadBalancerAttributes",
#                 "elasticloadbalancing:SetIpAddressType",
#                 "elasticloadbalancing:SetSecurityGroups",
#                 "elasticloadbalancing:SetSubnets",
#                 "elasticloadbalancing:DeleteLoadBalancer",
#                 "elasticloadbalancing:ModifyTargetGroup",
#                 "elasticloadbalancing:ModifyTargetGroupAttributes",
#                 "elasticloadbalancing:DeleteTargetGroup",
#                 "elasticloadbalancing:ModifyListenerAttributes",
#                 "elasticloadbalancing:ModifyCapacityReservation",
#                 "elasticloadbalancing:ModifyIpPools"
#             ],
#             "Resource": "*",
#             "Condition": {
#                 "Null": {
#                     "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
#                 }
#             }
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "elasticloadbalancing:AddTags"
#             ],
#             "Resource": [
#                 "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
#                 "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
#                 "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
#             ],
#             "Condition": {
#                 "StringEquals": {
#                     "elasticloadbalancing:CreateAction": [
#                         "CreateTargetGroup",
#                         "CreateLoadBalancer"
#                     ]
#                 },
#                 "Null": {
#                     "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
#                 }
#             }
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "elasticloadbalancing:RegisterTargets",
#                 "elasticloadbalancing:DeregisterTargets"
#             ],
#             "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
#         },
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "elasticloadbalancing:SetWebAcl",
#                 "elasticloadbalancing:ModifyListener",
#                 "elasticloadbalancing:AddListenerCertificates",
#                 "elasticloadbalancing:RemoveListenerCertificates",
#                 "elasticloadbalancing:ModifyRule",
#                 "elasticloadbalancing:SetRulePriorities"
#             ],
#             "Resource": "*"
#         }
#     ]
#   })
# }

# resource "aws_eks_addon" "eks-node-monitoring-agent" {
#   cluster_name = aws_eks_cluster.eks.name
#   addon_name   = "eks-node-monitoring-agent"
#   addon_version = "v1.7.0-eksbuild.1"
#   resolve_conflicts_on_update = "PRESERVE"
# }

# resource "aws_eks_addon" "metrics-server" {
#   cluster_name = aws_eks_cluster.eks.name
#   addon_name   = "metrics-server"
#   addon_version = "v0.9.0-eksbuild.5"
#   resolve_conflicts_on_update = "PRESERVE"
# }
