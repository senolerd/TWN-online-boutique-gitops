# ArgoCD: Platform Application yaml files
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
        "argocd.argoproj.io/sync-wave" = "30"
        # "alb.ingress.kubernetes.io/scheme" =  "internet-facing" # done at LoadBalancerConfiguration
        "alb.ingress.kubernetes.io/certificate-arn" = "${data.aws_acm_certificate.my-domain.arn}"
        "alb.ingress.kubernetes.io/ssl-redirect"    = "443" # Auto redirect all domains to TLS... meh.. i don't know
      }
    }
    spec = {
      gatewayClassName = "aws-alb-gc"
      infrastructure = {
        parametersRef = {
          group = "gateway.k8s.aws"
          kind  = "LoadBalancerConfiguration"
          name  = "public-alb-config"
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

# ArgoCD: ArgoCD UI HTTPRoute and Target Group Configuration
resource "local_file" "argocd-ui-targetGroupConfiguration" {
  filename = "../../argocd/platform/50-argocd-tgc.yaml"
  content = yamlencode({

    apiVersion = "gateway.k8s.aws/v1beta1"
    kind       = "TargetGroupConfiguration"
    metadata = {
      name        = "argocd-tgc"
      namespace   = "argocd"
      annotations = { "argocd.argoproj.io/sync-wave" = "40" }

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

resource "local_file" "argocd-ui-HTTPRoute" {
  filename = "../../argocd/platform/40-argocd-ui.yaml"
  content = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name        = "argocd-httproute"
      namespace   = "argocd"
      annotations = { "argocd.argoproj.io/sync-wave" = "50" }

    }
    spec = {
      hostnames = ["argocd.${data.terraform_remote_state.infra.outputs.hosted_zone_name}"]
      parentRefs = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "Gateway"
          name      = "public-gw"
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


