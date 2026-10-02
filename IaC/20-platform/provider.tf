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

provider "kubernetes" {
    host = data.terraform_remote_state.eks_core.outputs.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks_core.outputs.eks_cluster_ca_data)
    token = data.aws_eks_cluster_auth.cluster.token  
}

resource "kubernetes_manifest" "app-of-apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "app-of-apps-tf"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      source = {
        repoURL        = "https://github.com/senolerd/TWN-online-boutique-gitops.git"
        path           = "argocd-apps"
        targetRevision = "HEAD"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions= [
          "CreateNamespace=true",
          "ServerSideApply=true"
        ]
      }
    }
  }
}


