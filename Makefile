# A helper for IaC automation stages. 
# If you looking what this file is, it is Makefile, the commands are working on the console writing "make {command}, like "make infra". 
# The "make" command reads Makefile to find what to run.

help:
	reset
	@echo "\n For sanity, follow numeric orders to create whole environment. To delete, for same reason follow the reverse order.  \n\n\n \
	1 - make infra: creates AWS VPC and AWS EKS cluster,\n \
	2 - make bootstrap: installs argo on eks,\n \
	3 - make platform: creates app, \n \
	4 - make dns: dns works,\n"

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
# 	git add .
# 	git commit -m "Deployment removed ArgoCD apps cleared [skip ci]"
# 	git push origin main
