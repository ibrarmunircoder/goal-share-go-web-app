
resource "aws_security_group" "ecs_node_sg" {
  name   = "${var.prefix}-ecs-node-sg-${var.env}"
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb" {
  security_group_id            = aws_security_group.ecs_node_sg.id
  referenced_security_group_id = aws_security_group.load_balancer.id
  from_port                    = 32768
  to_port                      = 65535
  ip_protocol                  = "tcp"
}


resource "aws_vpc_security_group_egress_rule" "primary_sg_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.ecs_node_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


resource "aws_security_group" "load_balancer" {
  name   = "${var.prefix}-lb-sg-${var.env}"
  vpc_id = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.load_balancer.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.load_balancer.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

