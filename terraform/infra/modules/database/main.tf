resource "random_string" "password" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "password" {
  name  = "/${var.prefix}/${var.env}/database-password"
  type  = "SecureString"
  value = random_string.password.result
}

resource "aws_db_parameter_group" "this" {
  name   = "postgres17-no-ssl-pg"
  family = "postgres17"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

resource "aws_security_group" "db_sg" {
  name   = "${var.prefix}-db-sg-${var.env}"
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb" {
  description                  = "Allow app subnet to access db"
  security_group_id            = aws_security_group.db_sg.id
  referenced_security_group_id = var.ecs_node_sg_id
  from_port                    = 5432
  ip_protocol                  = "tcp"
  to_port                      = 5432
}


resource "aws_vpc_security_group_egress_rule" "db_sg_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.db_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


locals {
  is_production = var.env == "production"
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.prefix}-db-subnet-group-${var.env}"
  subnet_ids = var.db_subnets
}
resource "aws_db_instance" "this" {
  identifier             = "${var.prefix}-db-${var.env}"
  allocated_storage      = local.is_production ? 50 : 10
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "17.2"
  instance_class         = "db.t3.micro"
  username               = var.env
  db_name                = var.db_name
  publicly_accessible = false
  password               = random_string.password.result
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  skip_final_snapshot    = true
  multi_az               = local.is_production
  parameter_group_name = aws_db_parameter_group.this.name
}
