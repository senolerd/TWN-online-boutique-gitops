TARGET = terraform-IaC

help:
	@printf "\nFollow the numeric order to build; reverse it to tear down.\n\n"
	@printf "  1 - make infra      : VPC + EKS\n"
	@printf "  2 - make bootstrap  : Argo CD on EKS\n"
	@printf "  3 - make platform   : root app (platform + apps via Argo CD)\n"
	@printf "      make clean      : ordered teardown\n\n"

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
	git add .
	git commit -m "ArgoCD apps added [skip ci]"
	git push origin main

# dns:
# 	echo "platform"

clean:
	terraform -chdir=$(TARGET)/20-platform destroy -auto-approve
# 	git add .
# 	git commit -m "Deployment removed ArgoCD apps cleared [skip ci]"
# 	git push origin main

	terraform -chdir=$(TARGET)/10-bootstrap-argocd destroy -auto-approve
	terraform -chdir=$(TARGET)/00-infra destroy -auto-approve; \
	if [ $$? != 0 ] ; then \
		echo "If the VPC couldn't deleted, check out Endpoints and Security Groups. Delete manually if there is any tagged for cluster"; \
	fi 

argo-password:
	@kubectl -n argocd get secret argocd-initial-admin-secret \
	  -o jsonpath='{.data.password}' | base64 -d; echo