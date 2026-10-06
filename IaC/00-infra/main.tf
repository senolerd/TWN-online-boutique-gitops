# Update terraform.tfvars for new deployment environment 

module "vpc" {
  source              = "./modules/vpc"
  project_name        = var.project_name
  region              = var.region
  environment         = var.environment
  subnets             = var.subnets
  vpc_cidr            = var.vpc_cidr
  endpoints_interface = var.endpoints_interface
}

module "eks" {
  depends_on                 = [module.vpc]
  source                     = "./modules/eks"
  cluster_name               = var.project_name
  environment                = var.environment
  region                     = var.region
  private_subnets            = module.vpc.private_subnets
  vpc_endpoint_sg_for_eks_id = module.vpc.vpc_endpoint_sg_for_eks_id
  instance_types             = var.instance_types
  hosted_zone_name           = var.hosted_zone_name
}
