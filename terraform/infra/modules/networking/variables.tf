variable "region" {
  type        = string
  description = "Region where the resource(s) will be managed. Defaults to the region set in the provider configuration"
  default     = null
}

variable "prefix" {
  type        = string
  description = "The prefix to use for each resource under this module"
}

variable "cidr" {
  type        = string
  description = "The IPv4 CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "env" {
  type        = string
  description = "The name of the Environment (e.g., dev, staging, production)"
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "web_subnets" {
  type        = list(string)
  description = "A list of web subnets inside the VPC."
  default     = []
}

variable "app_subnets" {
  type        = list(string)
  description = "A list of application subnets inside the VPC."
  default     = []
}

variable "db_subnets" {
  type        = list(string)
  description = "A list of db subnets inside the VPC."
  default     = []
}

variable "azs" {
  type        = list(string)
  description = "A list of availability zones"
}

variable "create_igw" {
  description = "Controls if an Internet Gateway is created for public subnets and the related routes that connect them"
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
  type        = bool
  default     = false
}

variable "single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
  type        = bool
  default     = false
}

variable "one_nat_gateway_per_az" {
  description = "Should be true if you want only one NAT Gateway per availability zone. Requires `var.azs` to be set, and the number of `public_subnets` created to be greater than or equal to the number of availability zones specified in `var.azs`"
  type        = bool
  default     = false
}