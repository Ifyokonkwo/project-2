variable "rds_dbname" {
  description = "Database name for RDS database"
  type        = string
}
variable "rds_username" {
  description = "Username for RDS database"
  type        = string
}
variable "rds_password" {
  description = "Password for RDS database"
  type        = string
}
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}
variable "domain_name" {
  description = "Primary/root domain name"
  type        = string
  default     = "ifeanyi-okonkwo-05-training.com"
}

variable "new_relic_key" {
  type      = string
  sensitive = true
}

variable "new_relic_account_id" {
  type      = string
  sensitive = true
}

variable "scripts_bucket_name" {
  description = "Name of the S3 bucket to store scripts"
  type        = string
}