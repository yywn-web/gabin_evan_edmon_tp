# Entrees du module donnees : dimensionnement RDS et retention S3 fournis par
# l'environnement ; le secret arrive par une variable sensible, jamais en dur.

variable "name_prefix" {
  type = string
}

variable "region" {
  description = "Region de creation du bucket (appel AWS CLI)"
  type        = string
}

variable "data_subnet_ids" {
  description = "Sous-reseaux prives donnees (au moins 2 AZ)"
  type        = list(string)
  validation {
    condition     = length(var.data_subnet_ids) >= 2
    error_message = "RDS exige au moins 2 sous-reseaux dans 2 AZ differentes."
  }
}

variable "rds_sg_id" {
  type = string
}

variable "db_engine_version" {
  type    = string
  default = "8.0"
}

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_backup_retention_days" {
  description = "0 pour un environnement jetable, >= 1 pour la reference"
  type        = number
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  description = "Mot de passe administrateur RDS (fourni par secrets.auto.tfvars, non versionne)"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 12 && length(var.db_password) <= 41 && !can(regex("[/@\" ]", var.db_password))
    error_message = "12 a 41 caracteres, sans / @ \" ni espace."
  }
}

variable "s3_noncurrent_retention_days" {
  description = "Duree de conservation des anciennes versions d'objets"
  type        = number
}
