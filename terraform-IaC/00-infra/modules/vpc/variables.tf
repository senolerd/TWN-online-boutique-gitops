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

variable "environment" {
  type = string
}
