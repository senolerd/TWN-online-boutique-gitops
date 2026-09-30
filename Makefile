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
	terraform -chdirIaC/=00-infra init
	terraform -chdirIaC/=00-infra apply

bootstrap:
	terraform -chdirIaC/=10-bootstrap-argocd init
	terraform -chdirIaC/=10-bootstrap-argocd apply

platform:
	echo "platform"
	terraform -chdirIaC/=20-platform init
	terraform -chdirIaC/=20-platform apply

# dns:
# 	echo "platform"

clean:
	echo "kill'm all"
	terraform -chdirIaC/=20-platform destroy -auto-approve
	terraform -chdirIaC/=10-bootstrap-argocd destroy -auto-approve
	terraform -chdirIaC/=00-infra destroy -auto-approve