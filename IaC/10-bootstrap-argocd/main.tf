# Restore health assessment for argoproj.io/Application (removed in Argo CD 1.8).
# Without it, sync waves in the app-of-apps root don't wait for child apps to be
# Healthy — wave N+1 starts as soon as wave N's Application object exists.
#   Why/what: https://argo-cd.readthedocs.io/en/stable/operator-manual/health/#argocd-app
#   How (chart): configs.cm.* is rendered into argocd-cm
#     https://github.com/argoproj/argo-helm/tree/main/charts/argo-cd

resource "helm_release" "argocd" {
    name = "argocd"
    repository = "https://argoproj.github.io/argo-helm"
    chart = "argo-cd"
    version = "10.9.2"
    namespace = "argocd"
    create_namespace = true
    values = [yamlencode({
        configs = {
            params = {
                "server.insecure" = true 
            }

            cm = {
                "resource.customizations.health.argoproj.io_Application" = <<-EOT
                hs = {}
                hs.status = "Progressing"
                hs.message = ""
                if obj.status ~= nil and obj.status.health ~= nil then
                    hs.status = obj.status.health.status
                    if obj.status.health.message ~= nil then
                    hs.message = obj.status.health.message
                    end
                end
                return hs
                EOT

                "resource.customizations.health.gateway.networking.k8s.io_Gateway" = <<-EOT
                hs = { status = "Progressing", message = "Waiting for Gateway to be Programmed" }
                if obj.status ~= nil and obj.status.conditions ~= nil then
                    for _, c in ipairs(obj.status.conditions) do
                    if c.type == "Programmed" then
                        if c.status == "True" then
                        hs.status = "Healthy"
                        end
                        hs.message = c.message or hs.message
                    end
                    end
                end
                return hs
                EOT
            }
        }
    })]    
}
# Argocd CRD resources can be created after the Gateway Api CRDs are exist on Cluster. 
# Those custom health checks will let Argo to track CRD installation state, Gateway Api CRDs in this project.



