terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = data.terraform_remote_state.infra.outputs.eks_cluster_region
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.infra.outputs.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.infra.outputs.eks_cluster_ca_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "../00-infra/terraform.tfstate"
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.terraform_remote_state.infra.outputs.eks_cluster_name
}

