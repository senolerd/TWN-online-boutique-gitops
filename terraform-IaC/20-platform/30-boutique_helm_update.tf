#### Boutique helm chart update for  HTTPRoute and Target Group Configuration
resource "local_file" "boutique-TargetGroupConfiguration" {
  filename = "../../boutique-helm/templates/targetGroupConfig.yaml"
  content = yamlencode({

    apiVersion = "gateway.k8s.aws/v1beta1"
    kind       = "TargetGroupConfiguration"
    metadata = {
      name        = "frontend-tg"
      annotations = { "argocd.argoproj.io/sync-wave" = "10" }
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

resource "local_file" "boutique-HTTPRoute" {
  filename = "../../boutique-helm/templates/httproute.yaml"
  content = yamlencode({

    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name        = "boutique-${data.terraform_remote_state.infra.outputs.env}"
      annotations = { "argocd.argoproj.io/sync-wave" = "20" }
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



