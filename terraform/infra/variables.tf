variable "vpc_cidr" {
  type        = string
  description = "The IPv4 CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "project_name" {
  type        = string
  description = "The name of the project"
  default     = "goal-share-service"
}

variable "env" {
  type        = string
  description = "The name of the Environment (e.g., dev, staging, production)"
}