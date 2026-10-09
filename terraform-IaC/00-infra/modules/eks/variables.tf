variable "region" { type = string }
variable "project_name" { type = string }
variable "private_subnets" { }
variable "environment" {type = string }
variable "vpc_endpoint_sg_for_eks_id" { type = string }
variable "is_production" {
  type = bool
  default = false
}

variable "instance_types" { 
  description = "list of instance types that can be used by nodegroup creation"
  type = map(list(string))
  }

variable "hosted_zone_name" {
  type = string
}
