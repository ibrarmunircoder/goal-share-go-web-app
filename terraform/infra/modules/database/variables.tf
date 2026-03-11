variable "prefix" {
  type        = string
  description = "The prefix to use for each resource under this module"
}
variable "env" {
  type        = string
  description = "The name of the Environment (e.g., dev, staging, production)"
}

variable "vpc_id" {
  type        = string
  description = "The id of the VPC"
}

variable "ecs_node_sg_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "goalshare"
}

variable "db_subnets" {
  type        = list(string)
  description = "The list of db subnet ids to launch instances in"
}