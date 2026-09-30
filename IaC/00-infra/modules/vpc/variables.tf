variable "project_name" {
  type    = string
}

variable "region" {
  type = string
}

variable "vpc_cidr" {
  type    = string
}

variable "subnets" {
  # {subnet1 = { cidr = "10.10.1.0/24", az = "us-east-1a", is_public = false }}
  type = map(object({
    cidr      = string
    az        = string
    is_public = bool
  }))
}

variable "endpoints_interface" {
  # [ "ecr.api", "ecr.dkr", "ec2", "sts", "eks-auth", "elasticloadbalancing" ]
  type    = set(string)
}

variable "is_production" {
  # ToDo: For node group on private network; Nat Gateway for production, Endpoints for developmenet
  type    = bool
  default = false
}


variable "environment" {
  type = string
}
