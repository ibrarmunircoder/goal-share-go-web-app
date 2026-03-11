module "parameter_secure" {
  for_each = { for item in var.secrets : item => item }

  source  = "terraform-aws-modules/ssm-parameter/aws"
  version = "1.1.2"

  ignore_value_changes = true
  name                 = "/${var.prefix}/${var.env}/${lower(replace(each.key, "_", "-"))}"
  secure_type          = true
  value                = "example"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.prefix}/${var.env}/log-group"
  retention_in_days = local.log_rentention
}


locals {
  task_assume_role_polic = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
    ]
  })
}

resource "aws_iam_role" "execution_role" {
  name               = "${var.prefix}-execution-role-${var.env}"
  assume_role_policy = local.task_assume_role_polic
}

resource "aws_iam_policy" "execution_role_policy" {
  count = length(var.secrets) > 0 ? 1 : 0
  name  = "${var.prefix}-execution-policy-${var.env}"
  path  = "/"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ssm:GetParameters",
        ]
        Effect = "Allow"
        Resource = [
          for item in var.secrets : module.parameter_secure[item].ssm_parameter_arn
        ]
      },
      {
        Action = [
          "logs:CreateLogStream", "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Resource = [
          aws_cloudwatch_log_group.this.arn,
          "${aws_cloudwatch_log_group.this.arn}:*",
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "execution_policy" {
  count = length(var.secrets) > 0 ? 1 : 0

  role       = aws_iam_role.execution_role.name
  policy_arn = aws_iam_policy.execution_role_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "execution_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.execution_role.name
}

resource "aws_iam_role_policy_attachment" "execution_ec2" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  role       = aws_iam_role.execution_role.name
}

resource "aws_iam_role" "task_role" {
  name               = "${var.prefix}-task-role-${var.env}"
  assume_role_policy = local.task_assume_role_polic
}


resource "aws_ecs_task_definition" "this" {
  execution_role_arn = aws_iam_role.execution_role.arn
  family             = "${var.prefix}-go-app-${var.env}"
  task_role_arn      = aws_iam_role.task_role.arn
  network_mode       = "bridge"

  container_definitions = jsonencode([
    {
      cpu          = var.cpu
      essential    = true
      image        = "${var.image_registry}/${var.image_repository}:${var.image_tag}"
      memory       = var.memory
      name         = local.container_name
      portMappings = var.port != null ? [{ containerPort = var.port, hostPort: var.port }] : []

      environment = concat(
        [
          {
            name  = "GOOGLE_REDIRECT_URL"
            value = "http://${aws_lb.this.dns_name}/auth/google/callback"
          }
        ],
        [
          for item_name, item in var.config : {
            name  = upper(replace(item_name, "-", "_"))
            value = item
          }
        ]
      )

      secrets = [
        for item in var.secrets : {
          name      = upper(replace(item, "-", "_"))
          valueFrom = module.parameter_secure[item].ssm_parameter_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.this.region
          "awslogs-stream-prefix" = "svc"
        }
      }
    },
  ])
}

resource "aws_ecs_task_definition" "run_migration" {
  execution_role_arn = aws_iam_role.execution_role.arn
  family             = "${var.prefix}-go-migration-${var.env}"
  task_role_arn      = aws_iam_role.task_role.arn
  network_mode       = "bridge"

  container_definitions = jsonencode([
    {
      cpu          = var.cpu
      essential    = true
      image        = "${var.image_registry}/${var.image_repository}:${var.image_tag}"
      memory       = var.memory
      name         = local.container_name
      portMappings = var.port != null ? [{ containerPort = var.port, hostPort: var.migration_port }] : []

      environment = concat(
        [
          {
            name  = "GOOGLE_REDIRECT_URL"
            value = "http://${aws_lb.this.dns_name}/auth/google/callback"
          }
        ],
        [
          for item_name, item in var.config : {
            name  = upper(replace(item_name, "-", "_"))
            value = item
          }
        ]
      )

      secrets = [
        for item in var.secrets : {
          name      = upper(replace(item, "-", "_"))
          valueFrom = module.parameter_secure[item].ssm_parameter_arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.this.region
          "awslogs-stream-prefix" = "svc"
        }
      }
    },
  ])
}




resource "aws_ecs_service" "this" {
  cluster         = aws_ecs_cluster.this.id
  desired_count   = 1
  name            = "${var.prefix}-${var.env}"
  task_definition = aws_ecs_task_definition.this.arn
  force_new_deployment = true

  capacity_provider_strategy {
    base              = 1
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 100
  }

  load_balancer {
    container_name   = local.container_name
    container_port   = var.port
    target_group_arn = aws_lb_target_group.service.arn
  }


}
