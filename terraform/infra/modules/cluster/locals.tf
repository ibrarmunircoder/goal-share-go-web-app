

locals {
  is_production = var.env == "production"

  asg_desired_count = local.is_production ? 2 : 1
  asg_min_count     = local.is_production ? 2 : 1
  asg_max_count     = local.is_production ? 6 : 3

  instance_type = local.is_production ? "t2.large" : "t2.small"
  volume_size   = local.is_production ? 50 : 30

  log_rentention = local.is_production ? 30 : 14

  container_name = "${var.prefix}-app"
}