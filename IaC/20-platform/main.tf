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
            vpcTags     = { Name = data.terraform_remote_state.infra.outputs.vpc_name}
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
  filename = "${data.terraform_remote_state.infra.outputs.argocd-dir}/platform/gatewayclass.app.yaml"
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
  filename = "${data.terraform_remote_state.infra.outputs.argocd-dir}/platform/loadbalancerconfiguration.app.yaml"
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
  filename = "${data.terraform_remote_state.infra.outputs.argocd-dir}/platform/gateway.app.yaml"
  content = yamlencode({


    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "public-gw"
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

resource "local_file" "HTTPRoute-boutique" {
  filename = "../../boutique-helm/templates/httproute.yaml"
  content = yamlencode({

    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name =  "boutique-${data.terraform_remote_state.infra.outputs.env}"
    }
    spec = {
      parentRefs = [
        { 
          group = "gateway.networking.k8s.io"
          kind = "Gateway"
          name = "public-gw", 
          namespace = "gateway-system" }
      ]
      rules = [
        {
          matches = [ { path = { type = "PathPrefix", value = "/" } } ]
          backendRefs = [ { 
            name="frontend"
            port= 8080 
            group = "" 
            kind = "Service"
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
    kind = "TargetGroupConfiguration"
    metadata = { name = "frontend-tg" }
      
    spec = {
      targetReference = {  name =  "frontend"  }
      defaultConfiguration = { 
        targetType = "ip"
        healthCheckConfig = {healthCheckPath =  "/_healthz" }
      }
    }
  })
}

######## /Platform's k8s resources manifests


resource "local_file" "gateway-app" {
  filename = "${data.terraform_remote_state.infra.outputs.argocd-dir}/apps/30-gateway.app.yaml"
  content = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name        = "gateway-tf"
      namespace   = "argocd"
      annotations = { "argocd.argoproj.io/sync-wave" = "30" }
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
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


####### Route 53  

# data "aws_lb" "project_lb" {
#   region = data.terraform_remote_state.infra.outputs.region
#   tags = {
#     "elbv2.k8s.aws/cluster" = "my-proj-dev"
#   }
# }


# output "LB_INFO" {
#   value = data.aws_lb.project_lb
# }


# data "aws_route53_zone" "my-hosted-zone" {
#   name         = "${data.terraform_remote_state.infra.outputs.hosted_zone_name}"
# }

# resource "aws_route53_record" "boutique-A-record" {
#   zone_id = data.aws_route53_zone.my-hosted-zone.id
#   name    = "boutique.${data.aws_route53_zone.selected.name}"
#   type    = "A"
#   ttl     = "300"
# }




# ToDo: Add two url suffix for argo and boutique


# LB_INFO = {
#   "access_logs" = tolist([
#     {
#       "bucket" = ""
#       "enabled" = false
#       "prefix" = ""
#     },
#   ])
#   "arn" = "arn:aws:elasticloadbalancing:us-east-1:823899318117:loadbalancer/app/k8s-gateways-publicgw-ac898c8fca/b29e095aa976c5db"
#   "arn_suffix" = "app/k8s-gateways-publicgw-ac898c8fca/b29e095aa976c5db"
#   "client_keep_alive" = 3600
#   "connection_logs" = tolist([
#     {
#       "bucket" = ""
#       "enabled" = false
#       "prefix" = ""
#     },
#   ])
#   "customer_owned_ipv4_pool" = ""
#   "desync_mitigation_mode" = "defensive"
#   "dns_name" = "k8s-gateways-publicgw-ac898c8fca-914920390.us-east-1.elb.amazonaws.com"
#   "dns_record_client_routing_policy" = tostring(null)
#   "drop_invalid_header_fields" = false
#   "enable_cross_zone_load_balancing" = true
#   "enable_deletion_protection" = false
#   "enable_http2" = true
#   "enable_prefix_for_ipv6_source_nat" = "off"
#   "enable_tls_version_and_cipher_suite_headers" = false
#   "enable_waf_fail_open" = false
#   "enable_xff_client_port" = false
#   "enable_zonal_shift" = false
#   "enforce_security_group_inbound_rules_on_private_link_traffic" = ""
#   "health_check_logs" = tolist([
#     {
#       "bucket" = ""
#       "enabled" = false
#       "prefix" = ""
#     },
#   ])
#   "id" = "arn:aws:elasticloadbalancing:us-east-1:823899318117:loadbalancer/app/k8s-gateways-publicgw-ac898c8fca/b29e095aa976c5db"
#   "idle_timeout" = 60
#   "internal" = false
#   "ip_address_type" = "ipv4"
#   "ipam_pools" = tolist([])
#   "load_balancer_type" = "application"
#   "name" = "k8s-gateways-publicgw-ac898c8fca"
#   "preserve_host_header" = false
#   "region" = "us-east-1"
#   "secondary_ips_auto_assigned_per_subnet" = tonumber(null)
#   "security_groups" = toset([
#     "sg-00c0ddfe60fd5f38a",
#     "sg-074522fdee6519116",
#   ])
#   "subnet_mapping" = toset([
#     {
#       "allocation_id" = ""
#       "ipv6_address" = ""
#       "outpost_id" = ""
#       "private_ipv4_address" = ""
#       "subnet_id" = "subnet-04db35c633196fc15"
#     },
#     {
#       "allocation_id" = ""
#       "ipv6_address" = ""
#       "outpost_id" = ""
#       "private_ipv4_address" = ""
#       "subnet_id" = "subnet-071f56a6a0aedfa16"
#     },
#     {
#       "allocation_id" = ""
#       "ipv6_address" = ""
#       "outpost_id" = ""
#       "private_ipv4_address" = ""
#       "subnet_id" = "subnet-08b93d57b3228a4cf"
#     },
#     {
#       "allocation_id" = ""
#       "ipv6_address" = ""
#       "outpost_id" = ""
#       "private_ipv4_address" = ""
#       "subnet_id" = "subnet-0b48fe1478d46462c"
#     },
#   ])
#   "subnets" = toset([
#     "subnet-04db35c633196fc15",
#     "subnet-071f56a6a0aedfa16",
#     "subnet-08b93d57b3228a4cf",
#     "subnet-0b48fe1478d46462c",
#   ])
#   "tags" = tomap({
#     "elbv2.k8s.aws/cluster" = "my-proj-dev"
#     "gateway.k8s.aws.alb/resource" = "LoadBalancer"
#     "gateway.k8s.aws.alb/stack" = "gateway-system/public-gw"
#   })
#   "timeouts" = null /* object */
#   "vpc_id" = "vpc-027368ebcb64ecbd4"
#   "xff_header_processing_mode" = "append"
#   "zone_id" = "Z35SXDOTRQ7X7K"
# }

