locals {
  len_web_subnets = length(var.web_subnets)
  len_app_subnets = length(var.app_subnets)
  len_db_subnets  = length(var.db_subnets)

  vpc_id = aws_vpc.this.id
}

resource "aws_vpc" "this" {

  region = var.region

  cidr_block           = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = merge(
    {
      Name = var.prefix != null ? "${var.prefix}-vpc-${var.env}" : "vpc-${var.env}"
    },
    var.tags
  )

}




resource "aws_internet_gateway" "this" {
  count = local.create_web_subnets && var.create_igw ? 1 : 0

  region = var.region

  vpc_id = local.vpc_id

  tags = merge({
    Name = "${var.prefix}-igw"
  }, var.tags)
}

######################################################
#  Web Subents
######################################################

locals {
  create_web_subnets = local.len_web_subnets > 0
}

resource "aws_subnet" "web_subnet" {
  count = local.create_web_subnets ? local.len_web_subnets : 0

  region                  = var.region
  vpc_id                  = local.vpc_id
  cidr_block              = element(var.web_subnets, count.index)
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = format("${var.prefix}-web-subnet-%s", element(var.azs, count.index))
  }
}

resource "aws_route_table" "web" {
  count = local.create_web_subnets ? 1 : 0

  region = var.region

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = "${var.prefix}-web-subnets-rt"
    },
    var.tags,
  )
}


resource "aws_route_table_association" "web" {
  count = local.create_web_subnets && var.create_igw ? local.len_web_subnets : 0

  region = var.region

  subnet_id      = aws_subnet.web_subnet[count.index].id
  route_table_id = aws_route_table.web[0].id
}

resource "aws_route" "public_internet_gateway" {
  count = local.create_web_subnets && var.create_igw ? 1 : 0

  region = var.region

  route_table_id         = aws_route_table.web[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}


######################################################
#  App Subents
######################################################


locals {
  create_app_subnets = local.len_app_subnets > 0

}


resource "aws_subnet" "app_subnet" {
  count = local.create_app_subnets ? local.len_app_subnets : 0

  region            = var.region
  vpc_id            = local.vpc_id
  cidr_block        = element(var.app_subnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = format("${var.prefix}-app-subnet-%s", element(var.azs, count.index))
  }
}


resource "aws_route_table" "app" {
  count = local.create_app_subnets ? local.nat_gateway_count : 0

  region = var.region

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = var.single_nat_gateway ? "${var.prefix}-app-subnets-rt" : format(
        "${var.prefix}-app-subnets-rt-%s",
        element(var.azs, count.index),
      )
    },
    var.tags,
  )
}


resource "aws_route_table_association" "app" {
  count = local.create_web_subnets ? local.len_app_subnets : 0

  region = var.region

  subnet_id = aws_subnet.app_subnet[count.index].id
  route_table_id = element(
    aws_route_table.app[*].id,
    var.single_nat_gateway ? 0 : count.index,
  )
}

resource "aws_route" "private_nat_gateway" {
  count = var.enable_nat_gateway ? local.nat_gateway_count : 0

  region = var.region

  route_table_id         = element(aws_route_table.app[*].id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, count.index)

  timeouts {
    create = "5m"
  }
}




######################################################
#  Database Subents
######################################################

locals {
  create_db_subnets = local.len_db_subnets > 0

}

resource "aws_subnet" "db_subnet" {
  count = local.create_db_subnets ? local.len_db_subnets : 0

  region            = var.region
  vpc_id            = local.vpc_id
  cidr_block        = element(var.db_subnets, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = format("${var.prefix}-db-subnet-%s", element(var.azs, count.index))
  }
}

resource "aws_route_table" "db" {
  count = local.create_db_subnets ? 1 : 0

  region = var.region

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = format(
        "${var.prefix}-db-subnets-rt-%s",
        element(var.azs, count.index),
      )
    },
    var.tags,
  )
}


resource "aws_route_table_association" "db" {
  count = local.create_db_subnets ? local.len_db_subnets : 0

  region = var.region

  subnet_id      = aws_subnet.db_subnet[count.index].id
  route_table_id = aws_route_table.db[0].id
}


######################################################
#  NAT Gateways
######################################################

locals {
  nat_gateway_count = var.single_nat_gateway ? 1 : var.one_nat_gateway_per_az ? length(var.azs) : local.len_web_subnets
}

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? local.nat_gateway_count : 0

  region = var.region

  domain = "vpc"

  tags = merge(
    {
      "Name" = format(
        "${var.prefix}-%s",
        element(var.azs, var.single_nat_gateway ? 0 : count.index),
      )
    },
    var.tags,
  )

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? local.nat_gateway_count : 0

  region = var.region

  allocation_id = element(
    aws_eip.nat[*].id,
    var.single_nat_gateway ? 0 : count.index,
  )
  subnet_id = element(
    aws_subnet.web_subnet[*].id,
    var.single_nat_gateway ? 0 : count.index,
  )

  tags = merge(
    {
      "Name" = format(
        "${var.prefix}-%s",
        element(var.azs, var.single_nat_gateway ? 0 : count.index),
      )
    },
    var.tags,
  )

  depends_on = [aws_internet_gateway.this]
}
