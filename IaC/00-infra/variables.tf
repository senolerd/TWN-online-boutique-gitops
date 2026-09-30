variable "region" { type = string }
variable "vpc_cidr" { type = string }
variable "project_name" { type = string }

variable "environment" {
  # dev: Node Group nodes air tight, no internet access. Access to only AWS services (ecr, s3 etc) via Endpoints
  # prod: Node Group nodes have egress internet access via Global Nat Router. 
  description = "dev or prod"
  type = string
  default = "prod"
}

variable "endpoints_interface" { 
  description = "A set of service names for endpoint interfaces (except s3), like ('ecr.api', 'ecr.dkr', 'ec2')"
  type = set(string) 
  }

variable "subnets" {
  type = map(object({
    cidr      = string
    az        = string
    is_public = bool
  }))
}

variable "vpc_endpoint_sg_for_eks_id" {
  type = string
  default = null
}

variable "instance_types" { 
  description = "List of map image types that can be used by nodegroup creation"
  type = map(list(string))
}





