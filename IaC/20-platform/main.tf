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
        path           = "argocd/apps"
        targetRevision = "HEAD"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "ServerSideApply=true"
        ]
      }
    }
  }
}

resource "local_file" "gateway-api-crds-app" {
  filename = "${data.terraform_remote_state.eks_core.outputs.argocd-dir}/apps/10-gateway-api-crds.app.yaml"
  content = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name        = "gateway-api-crds-tf"
      namespace   = "argocd"
      annotations = { "argocd.argoproj.io/sync-wave" = "10" }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/kubernetes-sigs/gateway-api.git"
        path           = "config/crd/standard"
        targetRevision = "v1.6.1"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "kube-system"
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
  filename = "${data.terraform_remote_state.eks_core.outputs.argocd-dir}/apps/20-aws-load-balancer-controller.app.yaml"
  content = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "aws-load-balancer-controller-tf"
      namespace = "argocd"
      annotations = {
        "argocd.argoproj.io/sync-wave" = "20"
      }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://aws.github.io/eks-charts"
        chart          = "aws-load-balancer-controller"
        targetRevision = "x.y.z"
        helm = {
          releaseName = "aws-load-balancer-controller"
          valuesObject = {
            clusterName = "my-proj-dev"
            region      = data.terraform_remote_state.eks_core.outputs.region
            vpcId       = data.terraform_remote_state.eks_core.outputs.vpc_id
            serviceAccount = {
              create = true
              name   = "aws-load-balancer-controller"
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
        server    = "https://kubernetes.default.svc"
        namespace = "kube-system"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        retry = {
          limit   = 5
          backoff = { duration = "10s", factor = 2, maxDuration = "2m" }
        }
      }
    }
  })
}

######## Platform's k8s resources manifests



resource "local_file" "gatewayclass-yaml" {
  filename = "${data.terraform_remote_state.eks_core.outputs.argocd-dir}/platform/gatewayclass.app.yaml"
  content = yamlencode({

    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name        = "aws-alb"
      annotations = { "argocd.argoproj.io/sync-wave" = "0" }
    }
    spec = { controllerName = "gateway.k8s.aws/alb" }

  })
}

resource "local_file" "loadbalancerconfiguration-yaml" {
  filename = "${data.terraform_remote_state.eks_core.outputs.argocd-dir}/platform/loadbalancerconfiguration.app.yaml"
  content = yamlencode({

    apiVersion = "gateway.k8s.aws/v1beta1"
    kind       = "LoadBalancerConfiguration"
    metadata = {
      name        = "public-alb"
      namespace   = "gateway-system"
      annotations = { "argocd.argoproj.io/sync-wave" = "0" }
    }
    spec = { scheme = "internet-facing" }

  })
}

resource "local_file" "gateway-yaml" {
  filename = "${data.terraform_remote_state.eks_core.outputs.argocd-dir}/platform/gateway.app.yaml"
  content = yamlencode({


    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "public"
      namespace = "gateway-system"
    }
    spec = {
      gatewayClassName = "aws-alb"
      infrastructure = {
        parametersRef = {
          group = "gateway.k8s.aws"
          kind  = "LoadBalancerConfiguration"
          name  = "public-alb"
        }
      }
      listeners = [
        {
          name     = "http"
          protocol = "HTTP"
          port     = 80
          allowedRoutes = {
            namespaces = { from = "All" }
          }
        }
      ]
    }
  })
}

######## /Platform's k8s resources manifests


resource "local_file" "gateway-app" {
  filename = "${data.terraform_remote_state.eks_core.outputs.argocd-dir}/apps/30-gateway.app.yaml"
  content = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name        = "gateway-tf"
      namespace   = "argocd"
      annotations = { "argocd.argoproj.io/sync-wave" = "30" }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/senolerd/TWN-online-boutique-gitops.git"
        path           = "argocd/platform"
        targetRevision = "HEAD"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "kube-system"
      }
      syncPolicy = {
        automated   = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
        retry = {
          limit   = 5
          backoff = { duration = "10s", factor = 2, maxDuration = "2m" }
        }
      }
    }
  })
}

resource "local_file" "boutique-helm-app" {
  filename = "${data.terraform_remote_state.eks_core.outputs.argocd-dir}/apps/50-boutique-app-${data.terraform_remote_state.eks_core.outputs.env}.app.yaml"
  content = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "boutique-${data.terraform_remote_state.eks_core.outputs.env}-tf"
      namespace = "argocd"
      annotations = {
        "argocd.argoproj.io/sync-wave" : "50"
      }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/senolerd/TWN-online-boutique-gitops.git"
        path           = "boutique-helm"
        targetRevision = "HEAD"
      }
      destination = {
        namespace = "default"
        name      = "in-cluster"
      }
      syncPolicy = {
        automated = {
          prune    = true
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

