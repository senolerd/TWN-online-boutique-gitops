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

resource "local_file" "gateway-api-crds-app" {
  filename = "${data.terraform_remote_state.eks_core.outputs.argocd_app_dir}/gateway_api_crds.yaml"
  content = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name        = "gateway-api-crds-tf"
      namespace   = "argocd"
      annotations = { "argocd.argoproj.io/sync-wave" = "1" }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/kubernetes-sigs/gateway-api.git"
        path           = "config/crd/standard"
        targetRevision = "v1.6.1"
      }
      destination = {
        server = "https://kubernetes.default.svc"
        namespace =  "kube-system"
      }
      syncPolicy = {
        automated = {
          prune    = false
          selfHeal = true
        }
        syncOptions = ["ServerSideApply=true"]
        retry = {
          limit = 5
          backoff = {
            duration = "10s",
            factor   = 2,
          maxDuration = "2m" }
        }
      }

    }
  })
}

resource "local_file" "aws-load-balancer-controller-app" {
  filename = "${data.terraform_remote_state.eks_core.outputs.argocd_app_dir}/aws-load-balancer-controller.yaml"
  content = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind =  "Application"
    metadata = {
      name = "aws-load-balancer-controller-tf"
      namespace = "argocd"
      annotations = {
        "argocd.argoproj.io/sync-wave" =  "2"
      }
    }
    spec = {
      project = "default"
      source = {
        repoURL = "https://aws.github.io/eks-charts"
        chart =  "aws-load-balancer-controller"
        targetRevision =  "x.y.z"
        helm = {
          releaseName =  "aws-load-balancer-controller"
          valuesObject = {
            clusterName =  "my-proj-dev"
            region = data.terraform_remote_state.eks_core.outputs.region
            vpcId =  data.terraform_remote_state.eks_core.outputs.vpc_id
            serviceAccount = {
              create =  true
              name =  "aws-load-balancer-controller"
            }
            controllerConfig = {
              featureGates = {
                ALBGatewayAPI = true
              }
            }
          }
        }
      }
      destination = {
        server =  "https://kubernetes.default.svc"
        namespace =  "kube-system"
      }
      syncPolicy = {
        automated = {
          prune =  true
          selfHeal =  true
        }
        retry = {
          limit =  5
          backoff =  { duration =  "10s", factor =  2, maxDuration =  "2m" }
        }
      }
    }
  })
}

resource "local_file" "boutique-helm-app" {
  filename = "${data.terraform_remote_state.eks_core.outputs.argocd_app_dir}/boutique-app-${data.terraform_remote_state.eks_core.outputs.env}.yaml"
  content = yamlencode({
    apiVersion= "argoproj.io/v1alpha1"
    kind= "Application"
    metadata = {
      name = "boutique-${data.terraform_remote_state.eks_core.outputs.env}-tf" 
      namespace = "argocd" 
      annotations = {
        "argocd.argoproj.io/sync-wave": "3"
      }
      finalizers = [ "resources-finalizer.argocd.argoproj.io" ]
    }
    spec = {
      project = "default"
      source = {
        repoURL =  "https://github.com/senolerd/TWN-online-boutique-gitops.git"
        path = "boutique-helm"
        targetRevision = "HEAD"
      }
      destination = {
        namespace = "default"
        name =  "in-cluster" 
      }
      syncPolicy = {
        automated = {
          prune = true
          selfHeal = true 
        }
        syncOptions = [
          "CreateNamespace=true", 
          "ServerSideApply=true"
        ]
      }
    }
  })
}
