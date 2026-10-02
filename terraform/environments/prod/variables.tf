# Variables d'un environnement. Valeurs non secretes : <env>.tfvars (versionne).
# Valeurs secretes ou propres a chaque poste : secrets.auto.tfvars (ignore par Git).

variable "project" {
  type    = string
  default = "neocargo"
}

variable "environment" {
  description = "staging ou prod"
  type        = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type    = number
  default = 2
}

variable "admin_cidr" {
  description = "IP publique de l'operateur en /32 (secrets.auto.tfvars)"
  type        = string
}

variable "public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "asg_min" {
  type = number
}

variable "asg_desired" {
  type = number
}

variable "asg_max" {
  type = number
}

variable "cpu_target" {
  type    = number
  default = 50
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_backup_retention_days" {
  type = number
}

variable "db_name" {
  type    = string
  default = "trackfleet"
}

variable "db_username" {
  type    = string
  default = "dbadmin"
}

variable "db_password" {
  description = "Secret RDS (secrets.auto.tfvars, jamais versionne)"
  type        = string
  sensitive   = true
}

variable "s3_noncurrent_retention_days" {
  type = number
}
