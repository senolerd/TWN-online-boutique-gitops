# A helper for IaC automation stages. 
# If you looking what this file is, it is Makefile, the commands are working on the console writing "make {command}, like "make infra". 
# The "make" command reads Makefile to find what to run.

help:
	@printf "\nFollow the numeric order to build; reverse it to tear down.\n\n"
	@printf "  1 - make infra      : VPC + EKS\n"
	@printf "  2 - make bootstrap  : Argo CD on EKS\n"
	@printf "  3 - make platform   : root app (platform + apps via Argo CD)\n"
	@printf "      make clean      : ordered teardown\n\n"

infra:
	terraform -chdir=IaC/00-infra init
	terraform -chdir=IaC/00-infra refresh
	terraform -chdir=IaC/00-infra apply

bootstrap:
	terraform -chdir=IaC/10-bootstrap-argocd init
	terraform -chdir=IaC/10-bootstrap-argocd apply

platform:
	echo "platform"
	terraform -chdir=IaC/20-platform init
	terraform -chdir=IaC/20-platform apply
# 	git add .
# 	git commit -m "ArgoCD apps added [skip ci]"
# 	git push origin main

# dns:
# 	echo "platform"

clean:
	terraform -chdir=IaC/20-platform destroy -auto-approve
	terraform -chdir=IaC/10-bootstrap-argocd destroy -auto-approve
	terraform -chdir=IaC/00-infra destroy -auto-approve; \
	if [ $$? != 0 ] ; then \
		echo "If the VPC couldn't deleted, check out Endpoints and Security Groups. Delete manually if there is any tagged for cluster"; \
	fi 
	git add .
	git commit -m "Deployment removed ArgoCD apps cleared [skip ci]"
	git push origin main

argo-password:
	@kubectl -n argocd get secret argocd-initial-admin-secret \
	  -o jsonpath='{.data.password}' | base64 -d; echo