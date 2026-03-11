

locals {
  subnet_cidr_blocks = cidrsubnets(var.vpc_cidr, 4, 4, 4, 4, 4, 4, 4, 4, 4)

  web_subnet_cidrs = slice(local.subnet_cidr_blocks, 0, 3)
  app_subnet_cidrs = slice(local.subnet_cidr_blocks, 3, 6)
  db_subnet_cidrs  = slice(local.subnet_cidr_blocks, 6, 9)

  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
}


module "networking" {
  source = "./modules/networking"

  cidr                   = var.vpc_cidr
  app_subnets            = local.app_subnet_cidrs
  web_subnets            = local.web_subnet_cidrs
  db_subnets             = local.db_subnet_cidrs
  azs                    = local.azs
  enable_nat_gateway     = true
  one_nat_gateway_per_az = true

  prefix = var.project_name
  env    = var.env
}

module "cluser" {
  source = "./modules/cluster"

  prefix = var.project_name
  env    = var.env

  private_subnets = module.networking.app_subnet_ids
  public_subnets  = module.networking.web_subnet_ids
  vpc_id          = module.networking.vpc_id

  image_registry   = "${data.aws_caller_identity.this.account_id}.dkr.ecr.${data.aws_region.this.region}.amazonaws.com"
  image_repository = "goal-share"
  image_tag        = "latest"

  port = 8080

  config = {
    GOOSE_DRIVER = "postgres"
  }

  secrets = [
    "GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET",
    "GOOSE_DBSTRING",
    "POSTGRES_URL",
  ]
}


module "database" {
  source = "./modules/database"

  env = var.env
  vpc_id = module.networking.vpc_id

  db_subnets = module.networking.db_subnet_ids
  prefix = var.project_name
  ecs_node_sg_id = module.cluser.ecs_node_sg_id
}