# Depened on either the environment is "dev" or "prod"
# - If the environment is "dev", the private network is accessing to and only aws services via Endpoints (s3, eks-auth, ecr, sts etc. no internet access )
#   Developlent images are expected to stored at ECR. The endpoints according to docuements are not suitable for production level traffic but development.
# - If the environment is "prod", the private network is accessing to aws services via Regional NAT Gateway either to services or internet



######## VPC Egress for private network ########

## PROD environment egress with Regional NAT Gateway

resource "aws_nat_gateway" "regional-natgw" {
  count = var.environment == "prod" ? 1:0
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

resource "aws_ec2_tag" "name" {
  count = var.environment == "prod" ? 1:0
  resource_id = aws_nat_gateway.regional-natgw[0].route_table_id
  key = "Name"
  value = "🚫-RegionalNatGW-RTB-to-IGW-not_for_use" 
}

resource "aws_route_table" "nat-gw-rtb" {
  # Route table for PROD's private subnets 
  count = var.environment == "prod" ? 1:0
  vpc_id = aws_vpc.project_vpc.id
  region = var.region
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.regional-natgw[0].id
  }
  tags = {
    "Name" = "${var.environment}-${var.project_name}-NatGW-RTB"
    "managedBy" : "terraform"
    "env": var.environment
    "project": "${var.project_name}"
  }
}

resource "aws_route_table_association" "nat-gw-to-private" {
  # PROD's subnets are accessing now to world
  for_each = var.environment == "prod" ? local.private_subnets : {}
  subnet_id      =  each.value.id
  route_table_id = aws_route_table.nat-gw-rtb[0].id
}

## DEV environment egress with Endpoints

# SG

resource "aws_security_group" "vpc-endpoint-sg-for-eks" {
  count = var.environment == "dev" ? 1:0
  # All Interface endpoints will be added to this SG. Later, EKS's auto-created 
  # SG will be added to this SG as reference SG with 443 access permission 
  # as ingress to Endpoints come from EKS cluster
  description = "Grouping up endpoints created for EKS works"
  vpc_id      = aws_vpc.project_vpc.id
  tags = {
    "Name" = "EKS_ENDPOINTS-SG-${var.project_name}"
    "managedBy" : "terraform"
    "env": var.environment
  }
}

resource "aws_vpc_security_group_egress_rule" "endpoints-all-outbound-allow" {
  count = var.environment == "dev" ? 1:0
  description = "Allow any outbount trafic"
  security_group_id = aws_security_group.vpc-endpoint-sg-for-eks[0].id
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol         = "-1"
}

# Endpoint creations 
resource "aws_vpc_endpoint" "s3" {  
  # Gateway type endpoint for dev env
  count = var.environment == "dev" ? 1 : 0
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

resource "aws_vpc_endpoint" "interface-typed-endpoints" {
  # Interface type endpoints for dev env
  for_each =  var.environment == "dev" ? var.endpoints_interface : toset([])
  vpc_id       = aws_vpc.project_vpc.id
  service_name = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type = "Interface"
  subnet_ids = [ for subnet in local.private_subnets : subnet.id ]
  security_group_ids = [ aws_security_group.vpc-endpoint-sg-for-eks[0].id ]
  private_dns_enabled = true
  tags = { 
    "Name" : "${var.project_name}-${each.value}-if-ep" 
    "managedBy" : "terraform"
    "env": var.environment
  }
}
