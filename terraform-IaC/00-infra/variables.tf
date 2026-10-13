variable "project_name" { type = string }
variable "region" { type = string }
variable "vpc_cidr" { type = string }

variable "environment" {
  description = "dev or prod"
  type = string
  default = "prod"
}

variable "subnets" {
  type = map(object({
    cidr      = string
    az        = string
    is_public = bool
  }))
}

variable "instance_types" { 
  description = "List of map image types that can be used by nodegroup creation"
  type = map(list(string))
}

variable "argocd-dir" {
  description = "ArgoCD apps yaml file landing directory created at platform module"
  type = string
}

variable "hosted_zone_name" {
  description = "Domain name that hosted from AWS account holder"
  type = string
  default = "did-you-forgot-to-change-me.com"
}
