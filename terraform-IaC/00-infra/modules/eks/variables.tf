variable "region" { type = string }
variable "project_name" { type = string }
variable "private_subnets" { }
variable "environment" {type = string }

variable "instance_types" { 
  description = "list of instance types that can be used by nodegroup creation"
  type = map(list(string))
  }

variable "hosted_zone_name" {
  type = string
}
