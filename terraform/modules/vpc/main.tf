locals {
  az_count        = length(var.azs)
  newbits         = 8
  public_subnets  = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, local.newbits, i)]
  private_subnets = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, local.newbits, i + local.az_count)]
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                           = "${var.name_prefix}-public-${var.azs[count.index]}"
    "kubernetes.io/role/elb"                       = "1"
    "kubernetes.io/cluster/${var.name_prefix}-eks" = "shared"
  }
}

resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name                                           = "${var.name_prefix}-private-${var.azs[count.index]}"
    "kubernetes.io/role/internal-elb"              = "1"
    "kubernetes.io/cluster/${var.name_prefix}-eks" = "shared"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name_prefix}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.this]
  tags          = { Name = "${var.name_prefix}-nat" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-public-rt" }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  lifecycle {
    ignore_changes = [route]
  }
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-private-rt" }

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  lifecycle {
    ignore_changes = [route]
  }
}

resource "aws_route_table_association" "private" {
  count          = local.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ── SOC2 hardening ────────────────────────────────────────────────────────────

# VPC flow logs (ALL traffic) to CloudWatch Logs.
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/${var.name_prefix}-vpc/flow-logs"
  retention_in_days = var.log_retention_days

  tags = { Name = "${var.name_prefix}-vpc-flow-logs" }
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn    = aws_iam_role.flow_logs.arn

  tags = { Name = "${var.name_prefix}-vpc-flow-logs" }
}

# The VPC's default security group, adopted with no rules so it denies all traffic. Nothing in this stack
# uses it: EKS, nodes, ALB, EFS and DocumentDB all have their own security groups.
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${var.name_prefix}-default-sg-restricted" }
}

# The VPC's default network ACL (every subnet here uses it). Denies remote administration (SSH 22, RDP 3389)
# from the internet and allows everything else; security groups still do the fine-grained filtering.
# Inbound NACL rules match the DESTINATION port, so return traffic for outbound connections (destination =
# an ephemeral port) is unaffected.
resource "aws_default_network_acl" "this" {
  default_network_acl_id = aws_vpc.this.default_network_acl_id
  subnet_ids             = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)

  ingress {
    rule_no    = 100
    action     = "deny"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    rule_no    = 110
    action     = "deny"
    protocol   = "tcp"
    cidr_block = "0.0.0.0/0"
    from_port  = 3389
    to_port    = 3389
  }

  ingress {
    rule_no    = 200
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    action     = "allow"
    protocol   = "-1"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = { Name = "${var.name_prefix}-default-nacl" }
}
