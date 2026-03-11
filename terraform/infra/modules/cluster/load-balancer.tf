
resource "aws_lb" "this" {
  enable_deletion_protection = false
  idle_timeout               = 300
  internal                   = false
  load_balancer_type         = "application"
  preserve_host_header       = false
  subnets                    = var.public_subnets

  security_groups = [aws_security_group.load_balancer.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404 Not Found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_target_group" "service" {
  deregistration_delay              = 60
  load_balancing_cross_zone_enabled = true
  port                              = var.port
  protocol                          = "HTTP"
  vpc_id                            = var.vpc_id
  target_type                       = "instance"
}

resource "aws_lb_listener_rule" "service" {
  listener_arn = aws_lb_listener.http.arn

  action {
    target_group_arn = aws_lb_target_group.service.arn
    type             = "forward"
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}