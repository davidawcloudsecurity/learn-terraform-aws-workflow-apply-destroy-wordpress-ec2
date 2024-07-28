variable "region" {
  description = "The AWS region to deploy in"
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnet"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "A list of CIDR blocks for the private subnet for app servers"
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "A list of CIDR blocks for the private subnet for database servers"
  type        = list(string)
}

variable "ami_id" {
  description = "The AMI ID for the instances"
  type        = string
}

variable "instance_type" {
  description = "The instance type for the instances"
  type        = string
}

variable "instance_count" {
  description = "Number of instances for each role"
  type        = number
}

variable "key_name" {
  description = "The key name to use for the instances"
  type        = string
}

variable "rds_allocated_storage" {
  description = "The allocated storage for the RDS instance"
  type        = number
}

variable "rds_instance_class" {
  description = "The instance class for the RDS instance"
  type        = string
}

variable "rds_db_name" {
  description = "The database name for the RDS instance"
  type        = string
}

variable "rds_username" {
  description = "The database username for the RDS instance"
  type        = string
}

variable "rds_password" {
  description = "The database password for the RDS instance"
  type        = string
}
