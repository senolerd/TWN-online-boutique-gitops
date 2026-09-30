resource "aws_vpc" "project_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    "Name" : "${var.environment}-${var.project_name}"
    "managedBy" : "terraform"
    "project": "${var.project_name}"
  }
}

resource "aws_default_route_table" "name" {
  default_route_table_id = aws_vpc.project_vpc.default_route_table_id
  tags = {
    "Name": "${var.environment}-${var.project_name}-defRTB",
    "managedBy" : "terraform",
    "env": var.environment

  }
}

resource "aws_subnet" "project_subnets" {
  # If an resource has for_each, the map object that created by for_each 
  # can be accessed by full name of the resource (ex: aws_subnet.project_subnets)
  for_each = var.subnets

  vpc_id            = aws_vpc.project_vpc.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  
  tags = {
    "Name" : "${var.environment}-${var.project_name}-${each.value.az}-${each.value.is_public ? "public" : "priv"}"
    "is_public" : each.value.is_public
    "managedBy" : "terraform"
    "project": "${var.project_name}"
    "kubernetes.io/role/elb": each.value.is_public ? 1 : 0
    "env": var.environment
  }
}

#### Internet access for Public network

resource "aws_internet_gateway" "IGV" {
  # Every VPC need a internet gateway at some point
  vpc_id = aws_vpc.project_vpc.id
  tags = {
    "Name" : "${var.environment}-${var.project_name}_IGW"
    "managedBy" : "terraform"
    "env": var.environment
    "project": "${var.project_name}"
  }
}

resource "aws_route_table" "IGW-RT" {
  vpc_id = aws_vpc.project_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGV.id
  }
  tags = {
    "Name" : "${var.environment}-${var.project_name}-IGW_RT"
    "managedBy" : "terraform"
    "env": var.environment
    "project": "${var.project_name}"
  }
}

resource "aws_route_table_association" "igw_rt_associate_with_pub_subnets" {
  for_each       = local.public_subnets
  subnet_id      = each.value.id
  route_table_id = aws_route_table.IGW-RT.id
}

locals {
  public_subnets = {
    for k, subnet in aws_subnet.project_subnets :
    k => subnet
    if var.subnets[k].is_public == true
  }

  private_subnets = {
    for k, subnet in aws_subnet.project_subnets :
    k => subnet
    if var.subnets[k].is_public == false
  }
}




