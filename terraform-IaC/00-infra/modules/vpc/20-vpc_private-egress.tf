######## VPC Egress for private network ########

resource "aws_nat_gateway" "regional-natgw" {
  availability_mode = "regional"
  connectivity_type = "public"
  vpc_id = aws_vpc.project_vpc.id
  region = var.region
  tags = {
    "Name" : "${var.environment}-${var.project_name}-RegionalNatGW"
    "managedBy" : "terraform"
    "env": var.environment
    "project": "${var.project_name}"
  }
}

resource "aws_ec2_tag" "regional-natgw-name-tag" {
  resource_id = aws_nat_gateway.regional-natgw.route_table_id
  key = "Name"
  value = "🚫-RegionalNatGW-RTB-to-IGW-not_for_use" 
}

resource "aws_route_table" "nat-gw-rtb" {
  vpc_id = aws_vpc.project_vpc.id
  region = var.region
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.regional-natgw.id
  }
  tags = {
    "Name" = "${var.environment}-${var.project_name}-NatGW-RTB"
    "managedBy" : "terraform"
    "env": var.environment
    "project": "${var.project_name}"
  }
}

resource "aws_route_table_association" "nat-gw-to-private" {
  for_each = local.private_subnets
  subnet_id      =  each.value.id
  route_table_id = aws_route_table.nat-gw-rtb.id
}

# SG
resource "aws_security_group" "vpc-endpoint-sg-for-eks" {
  description = "Grouping up endpoints created for EKS works"
  vpc_id      = aws_vpc.project_vpc.id
  tags = {
    "Name" = "EKS_ENDPOINTS-SG-${var.project_name}"
    "managedBy" : "terraform"
    "env": var.environment
  }
}

resource "aws_vpc_security_group_egress_rule" "endpoints-all-outbound-allow" {
  description = "Allow any outbount trafic"
  security_group_id = aws_security_group.vpc-endpoint-sg-for-eks.id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol         = "-1"
}

resource "aws_vpc_endpoint" "s3" {  
  # Gateway type s3 endpoint
  vpc_id       = aws_vpc.project_vpc.id
  service_name = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [aws_vpc.project_vpc.main_route_table_id]
  tags = { 
    "Name" : "${var.project_name}-s3-gw-ep" 
    "managedBy" : "terraform"
    "env": var.environment
    }
}
