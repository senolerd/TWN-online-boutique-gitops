resource "aws_iam_policy" "lbc_json_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy-${aws_eks_cluster.eks.name}"
  policy = file("${path.module}/iam_policy.json")
}

resource "aws_iam_role" "lbc_role" {
  name = "lbc_role-${aws_eks_cluster.eks.name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [ "sts:AssumeRole", "sts:TagSession" ]
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lbc_role_policy_attach" {
  role       = aws_iam_role.lbc_role.name
  policy_arn = aws_iam_policy.lbc_json_policy.arn
}

resource "aws_eks_pod_identity_association" "example" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc_role.arn
}