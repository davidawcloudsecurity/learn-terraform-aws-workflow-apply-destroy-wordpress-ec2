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

variable "ssm_role" {
  description = "Role name to use SSM"
  type        = string
  default     = "AmazonSSMManagedInstanceRole03"
}

variable "ssm_instance_profile" {
  description = "Role name to use SSM"
  type        = string
  default     = "AmazonSSMManagedInstanceProfile03"
}

/*
variable "key_name" {
  description = "The key name to use for the instances"
  type        = string
  default     = ""
}
*/
variable "db_ami_id" {
  description = "The AMI ID for the DB instance"
  type        = string
}

variable "db_instance_type" {
  description = "The instance type for the DB instance"
  type        = string
}

variable "db_root_password" {
  description = "The root password for the DB instance"
  type        = string
  sensitive   = true
}

variable "private_key_path" {
  description = "Path to the private key for SSH"
  type        = string
}
