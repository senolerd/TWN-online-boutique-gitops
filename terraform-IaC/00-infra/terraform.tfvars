project_name = "my-proj"
region       = "us-east-1"
environment = "prod"
vpc_cidr = "10.10.0.0/16"
subnets = {
  private-1a = { cidr = "10.10.0.0/20",  az = "us-east-1a", is_public = false } //4096 
  private-1b = { cidr = "10.10.16.0/20", az = "us-east-1b", is_public = false } //4096
  private-1c = { cidr = "10.10.32.0/20", az = "us-east-1c", is_public = false } //4096
  private-1d = { cidr = "10.10.48.0/20", az = "us-east-1d", is_public = false } //4096
  
  public-1a  = { cidr = "10.10.64.0/24", az = "us-east-1a", is_public = true }
  public-1b  = { cidr = "10.10.65.0/24", az = "us-east-1b", is_public = true }
  public-1c  = { cidr = "10.10.66.0/24", az = "us-east-1c", is_public = true }
  public-1d  = { cidr = "10.10.67.0/24", az = "us-east-1d", is_public = true }
}

instance_types = {
  dev =  ["t3.small"] 
  prod = ["t3.medium"]
} 

argocd-dir= "../../argocd"
hosted_zone_name = "senolerd.xyz"
