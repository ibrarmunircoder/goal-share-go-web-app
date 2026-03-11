variable "prefix" {
  type        = string
  description = "The prefix to use for each resource under this module"
}

variable "vpc_id" {
  type        = string
  description = "The id of the VPC"
}


variable "env" {
  type        = string
  description = "The name of the Environment (e.g., dev, staging, production)"
}

variable "secrets" {
  default = []
  type    = list(string)
}


variable "private_subnets" {
  type        = list(string)
  description = "The list of private subnet ids to launch instances in"
}

variable "public_subnets" {
  type        = list(string)
  description = "The list of public subnet ids to launch instances in"
}

variable "cpu" {
  default = 256
  type    = number
}

variable "memory" {
  default = 512
  type    = number
}

variable "image_registry" {
  type = string
}

variable "image_repository" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "port" {
  default = 8080
  type    = number
}

variable "migration_port" {
  default = 8081
  type    = number
}

variable "config" {
  default = {}
  type    = map(string)
}