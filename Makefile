# It is a helper Makefile to bootstrap infrastructure. Not part of the Jenkins pipeline. 
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
	git add .
	git commit -m "Deployment removed. ArgoCD apps are cleared. [skip ci]"
	git push origin main

# 	terraform -chdir=$(TARGET)/10-bootstrap-argocd destroy -auto-approve
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



# TODO:

# 1. modules/vpc/20-vpc_private-egress.tf
#    - Remove the count/for_each env conditions from the NAT gateway, its route table, the route table tag and the subnet associations, so they're always created.
#    - Delete the dev endpoint SG, its egress rule and the interface endpoints.
# 2. Keep the S3 gateway endpoint for every env and attach it to the NAT route table. It's free, and ECR image layers are served from S3, so image pulls skip NAT data processing charges. It's a cheap win on a small budget.
# 3. Remove the dev-only wiring:
#    - the SG ingress rule in modules/eks/10-eks_controller.tf
#    - the vpc_endpoint_sg_for_eks_id output and variables
#    - endpoints_interface in the variables, main.tf and terraform.tfvars
#    - the unused is_production variables in both modules
# 4. Update the comments in variables.tf and at the top of the egress file, and the README line "In dev, node group egress is restricted to explicit VPC endpoints only".

# Important for the live prod cluster: removing count changes resource addresses, for example aws_nat_gateway.regional-natgw[0] becomes aws_nat_gateway.regional-natgw. Without moved { } blocks, Terraform would destroy and recreate the NAT gateway and cut node egress while it does. I'd add moved blocks so the plan shows no changes to prod networking apart from the S3 endpoint being added.

# Want me to make these changes? I'd finish with terraform validate, plus a terraform plan so you can confirm nothing gets replaced.