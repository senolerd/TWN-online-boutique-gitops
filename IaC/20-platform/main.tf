
#### APP of APPS
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

#### ArgoCD  (App of Apps pattern ) apps/ yaml files
resource "local_file" "gateway-api-crds-app" {
  filename = "${data.terraform_remote_state.infra.outputs.argocd-dir}/apps/10-gateway-api-crds.app.yaml"
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
  filename = "${data.terraform_remote_state.infra.outputs.argocd-dir}/apps/20-aws-load-balancer-controller.app.yaml"
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
        targetRevision = "3.5.0"
        helm = {
          releaseName = "aws-load-balancer-controller"
          valuesObject = {
            clusterName = data.terraform_remote_state.infra.outputs.vpc_name
            region      = data.terraform_remote_state.infra.outputs.region
            vpcTags     = { Name = data.terraform_remote_state.infra.outputs.vpc_name }
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

resource "local_file" "platform-app" {
  filename = "${data.terraform_remote_state.infra.outputs.argocd-dir}/apps/30-platform.app.yaml"
  content = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name        = "platform-tf"
      namespace   = "argocd"
      finalizers  = ["resources-finalizer.argocd.argoproj.io"]
      annotations = {"argocd.argoproj.io/sync-wave" = "30" }
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
        namespace = "gateway-system"
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
  filename = "${data.terraform_remote_state.infra.outputs.argocd-dir}/apps/50-boutique-app-${data.terraform_remote_state.infra.outputs.env}.app.yaml"
  content = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "boutique-${data.terraform_remote_state.infra.outputs.env}-tf"
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
        namespace = "boutique-${data.terraform_remote_state.infra.outputs.env}" # prod
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




#### ArgoCD: platform/ standalone (no App of Apps pattern) yaml files

resource "local_file" "platform-gatewayclass-yaml" {
  filename = "${data.terraform_remote_state.infra.outputs.argocd-dir}/platform/10-gatewayclass.app.yaml"
  content = yamlencode({

    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"
    metadata = {
      name        = "aws-alb-gc"
      annotations = { "argocd.argoproj.io/sync-wave" = "10" }
    }
    spec = { controllerName = "gateway.k8s.aws/alb" }

  })
}

resource "local_file" "loadbalancerconfiguration-yaml" {
  filename = "${data.terraform_remote_state.infra.outputs.argocd-dir}/platform/20-loadbalancerconfiguration.app.yaml"
  content = yamlencode({

    apiVersion = "gateway.k8s.aws/v1beta1"
    kind       = "LoadBalancerConfiguration"
    metadata = {
      name        = "public-alb-config"
      namespace   = "gateway-system"
      annotations = { "argocd.argoproj.io/sync-wave" = "20" }
    }
    spec = { scheme = "internet-facing" }

  })
}

data "aws_acm_certificate" "my-domain" {
  domain   = data.terraform_remote_state.infra.outputs.hosted_zone_name
  statuses = ["ISSUED"]
}

resource "local_file" "gateway-yaml" {
  filename = "${data.terraform_remote_state.infra.outputs.argocd-dir}/platform/30-gateway.yaml"
  content = yamlencode({


    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "public-gw"
      namespace = "gateway-system"
      annotations = {
        annotations = { "argocd.argoproj.io/sync-wave" = "30" }
        # "alb.ingress.kubernetes.io/scheme" =  "internet-facing" # done at LoadBalancerConfiguration
        "alb.ingress.kubernetes.io/certificate-arn" = data.aws_acm_certificate.my-domain.arn
        "alb.ingress.kubernetes.io/ssl-redirect"    = "443" # Auto redirect all domains to TLS... meh.. i don't know
      }
    }
    spec = {
      gatewayClassName = "aws-alb-gc"
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
        },
        {
          name     = "https"
          protocol = "HTTPS"
          port     = 443
          allowedRoutes = {
            namespaces = { from = "All" }
          }
        }
      ]
    }
  })
}

# ArgoCD: route and TGC
resource "local_file" "HTTPRoute-argocd-ui" {
  filename = "../../argocd/platform/40-argocd-ui.yaml"
  content = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name = "argocd-${data.terraform_remote_state.infra.outputs.env}-tgc"
      namespace = "argocd"
      annotations = { "argocd.argoproj.io/sync-wave" = "40" }

    }
    spec = {
      hostnames = [ "argocd.${data.terraform_remote_state.infra.outputs.hosted_zone_name}" ]
      parentRefs = [
        { 
          group = "gateway.networking.k8s.io"
          kind  = "Gateway"
          name  = "public-gw"
          namespace = "gateway-system" 
        }
      ]
      rules = [
        {
          matches = [{ path = { type = "PathPrefix", value = "/" } }]
          backendRefs = [
            {
              name   = "argocd-server"
              port   = 80
              group  = ""
              kind   = "Service"
              weight = 1
            }
          ]
        }
      ]
    }
  })
}

resource "local_file" "targetGroupConfiguration-argocd-ui" {
  filename = "../../argocd/platform/50-argocd-tgc.yaml"
  content = yamlencode({

    apiVersion = "gateway.k8s.aws/v1beta1"
    kind       = "TargetGroupConfiguration"
    metadata   = { 
      name = "argocd-tgc" 
      namespace = "argocd"
      annotations = { "argocd.argoproj.io/sync-wave" = "50" }

    }
    spec = {
      targetReference = { name = "argocd-server" }
      defaultConfiguration = {
        targetType        = "ip"
        healthCheckConfig = { healthCheckPath = "/healthz" }
      }
    }
  })
}


#### Boutique helm chart update for route and TGC
resource "local_file" "HTTPRoute-boutique" {
  filename = "../../boutique-helm/templates/httproute.yaml"
  content = yamlencode({

    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name = "boutique-${data.terraform_remote_state.infra.outputs.env}"
      annotations = {
        annotations = { "argocd.argoproj.io/sync-wave" = "10" }
      }      
    }
    spec = {
      hostnames = ["boutique.${data.terraform_remote_state.infra.outputs.hosted_zone_name}"]
      parentRefs = [
        {
          group = "gateway.networking.k8s.io"
          kind  = "Gateway"
          name  = "public-gw",
        namespace = "gateway-system" }
      ]
      rules = [
        {
          matches = [{ path = { type = "PathPrefix", value = "/" } }]
          backendRefs = [{
            name   = "frontend"
            port   = 8080
            group  = ""
            kind   = "Service"
            weight = 1
          }]
        }
      ]
    }
  })
}

resource "local_file" "TargetGroupConfiguration-boutique" {
  filename = "../../boutique-helm/templates/targetGroupConfig.yaml"
  content = yamlencode({

    apiVersion = "gateway.k8s.aws/v1beta1"
    kind       = "TargetGroupConfiguration"
    metadata   = { 
      name = "frontend-tg" 
      annotations = {
        annotations = { "argocd.argoproj.io/sync-wave" = "20" }
      } 
    }

    spec = {
      targetReference = { name = "frontend" }
      defaultConfiguration = {
        targetType        = "ip"
        healthCheckConfig = { healthCheckPath = "/_healthz" }
      }
    }
  })
}



















