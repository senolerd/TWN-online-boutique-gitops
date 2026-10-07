terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = data.terraform_remote_state.eks_core.outputs.eks_cluster_region
}

data "terraform_remote_state" "eks_core" {
  backend = "local"
  config = {
    path = "../00-infra/terraform.tfstate"
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.eks_core.outputs.eks_cluster_name
}

provider "helm" {
  kubernetes = {
    host = data.terraform_remote_state.eks_core.outputs.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_core.outputs.eks_cluster_ca_data)
    token = data.aws_eks_cluster_auth.cluster.token
  }
}

