# It is a helper Makefile to bootstrap infrastructure. Not part of the Jenkins pipeline. 
TARGET = terraform-IaC

help:
	@printf "\nFollow the numeric order to build; reverse it to tear down.\n\n"
	@printf "  1 - make infra      : VPC + EKS\n"
	@printf "  2 - make bootstrap  : Argo CD on EKS\n"
	@printf "  3 - make platform   : root app (platform + apps via Argo CD)\n"
	@printf "      make clean      : ordered teardown\n\n"
	@printf "      make argo-password : Get argo admin initial password (after 'aws eks update-kubeconfig')\n"
	@printf "      make grafana-password : Get grafana admin initial password (after 'aws eks update-kubeconfig')\n"

infra:
	terraform -chdir=$(TARGET)/00-infra init
	terraform -chdir=$(TARGET)/00-infra refresh
	terraform -chdir=$(TARGET)/00-infra apply

bootstrap:
	terraform -chdir=$(TARGET)/10-bootstrap-argocd init
	terraform -chdir=$(TARGET)/10-bootstrap-argocd apply

platform:
	echo "platform"
	terraform -chdir=$(TARGET)/20-platform init
	terraform -chdir=$(TARGET)/20-platform apply
	echo "*** \n\nArgoCD App of Apps resources ready to push\n\n"
	git add .
	git commit -m "ArgoCD apps added [skip ci]"
	git push origin main

clean:
	terraform -chdir=$(TARGET)/20-platform destroy -auto-approve
# 	git add .
# 	git commit -m "Deployment removed. ArgoCD apps are cleared. [skip ci]"
# 	git push origin main

	terraform -chdir=$(TARGET)/10-bootstrap-argocd destroy -auto-approve
	terraform -chdir=$(TARGET)/00-infra destroy -auto-approve; \
	if [ $$? != 0 ] ; then \
		echo "If the VPC couldn't deleted, check out Endpoints and Security Groups. Delete manually if there is any tagged for cluster"; \
	fi 

argo-password:
	@kubectl -n argocd get secret argocd-initial-admin-secret \
	  -o jsonpath='{.data.password}' | base64 -d; echo

grafana-password:
	@kubectl get secret -n monitoring -l app.kubernetes.io/name=grafana \
	-o jsonpath="{.items[0].data.admin-password}" | base64 --decode ; echo

# ToDo: httpRoute hostnames can be echo-ed for convince