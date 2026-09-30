project_name = "my-proj"
region       = "us-east-1"
environment = "prod"
vpc_cidr = "10.10.0.0/16"
subnets = {
  # ToDo: Pull subnets to /22 or /21, 24 might be small sometimes 
  subnet1 = { cidr = "10.10.1.0/24", az = "us-east-1a", is_public = false }
  subnet2 = { cidr = "10.10.2.0/24", az = "us-east-1a", is_public = true }
  subnet3 = { cidr = "10.10.3.0/24", az = "us-east-1b", is_public = false }
  subnet4 = { cidr = "10.10.4.0/24", az = "us-east-1b", is_public = true }
  subnet5 = { cidr = "10.10.5.0/24", az = "us-east-1c", is_public = false }
  subnet6 = { cidr = "10.10.6.0/24", az = "us-east-1c", is_public = true }
  subnet7 = { cidr = "10.10.7.0/24", az = "us-east-1d", is_public = false }
  subnet8 = { cidr = "10.10.8.0/24", az = "us-east-1d", is_public = true }
}
endpoints_interface = [ "ecr.api", "ecr.dkr", "ec2", "sts", "eks-auth", "elasticloadbalancing" ]

instance_types = {
  dev =  ["t3.small"] 
  prod = ["t3.medium"]
} 
