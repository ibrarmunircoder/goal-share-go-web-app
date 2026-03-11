#############################################################
# ECS Cluster
#############################################################

resource "aws_ecs_cluster" "this" {
  name = "${var.prefix}-cluster-${var.env}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

#############################################################
# Launch Template
#############################################################


resource "aws_iam_role" "instance_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "instance_role_attachment" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "instance_profile" {
  role = aws_iam_role.instance_role.name
}


resource "aws_launch_template" "this" {
  name          = "${var.prefix}-template-${var.env}"
  image_id      = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  instance_type = local.instance_type

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      delete_on_termination = true
      volume_size           = local.volume_size
      volume_type           = "gp2"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }

  user_data = base64encode(templatefile("${path.module}/templates/ecs.sh", {
    cluster_name = aws_ecs_cluster.this.name
  }))

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ecs_node_sg.id]
  }
}

#############################################################
# Auto Scaling group
#############################################################

resource "aws_autoscaling_group" "this" {
  name             = "${var.prefix}-asg-${var.env}"
  desired_capacity = local.asg_desired_count
  min_size         = local.asg_min_count
  max_size         = local.asg_max_count

  health_check_grace_period = 300

  vpc_zone_identifier = var.private_subnets

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    triggers = ["tag"]

    preferences {
      min_healthy_percentage = 90
    }
  }

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = false
  }
}

resource "aws_autoscaling_policy" "this" {

  autoscaling_group_name = aws_autoscaling_group.this.name
  name                   = "${var.prefix}-cpu-target-tracking"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50
  }
}

resource "aws_ecs_capacity_provider" "this" {

  name = "${var.prefix}-asg-cap-provider-${var.env}"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.this.arn

    managed_scaling {
      status = "DISABLED"
    }
  }

  depends_on = [aws_security_group.load_balancer]
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    base              = 1
    weight            = 100
  }
}