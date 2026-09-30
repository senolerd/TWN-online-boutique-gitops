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
        }
        }
    })]    
}