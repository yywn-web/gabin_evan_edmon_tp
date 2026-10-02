# Entrees du module compute : dimensionnement et branchement reseau fournis
# par l'environnement appelant ; aucune valeur propre a staging/prod ici.

variable "name_prefix" {
  description = "Prefixe des noms, ex. neocargo-prod (32 caracteres max pour ALB/TG)"
  type        = string
  validation {
    condition     = length(var.name_prefix) <= 26
    error_message = "26 caracteres max : les noms ALB/TG (prefixe + suffixe) sont limites a 32."
  }
}

variable "project" {
  description = "Nom du projet, pose en tag Project sur les instances (filtre Ansible)"
  type        = string
}

variable "environment" {
  description = "staging ou prod, pose en tag Environment (groupes Ansible)"
  type        = string
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment doit valoir staging ou prod."
  }
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Sous-reseaux de l'ALB et du bastion"
  type        = list(string)
}

variable "app_subnet_ids" {
  description = "Sous-reseaux prives de l'ASG"
  type        = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "app_sg_id" {
  type = string
}

variable "bastion_sg_id" {
  type = string
}

variable "network_ready" {
  description = "Jeton du module reseau : retarde l'ASG jusqu'a la sortie Internet prete"
  type        = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
  validation {
    condition     = contains(["t3.micro", "t3.small", "t2.micro"], var.instance_type)
    error_message = "Tailles autorisees par le quota academique : t3.micro, t3.small, t2.micro."
  }
}

variable "asg_min" {
  type = number
}

variable "asg_desired" {
  type = number
}

variable "asg_max" {
  type = number
  validation {
    condition     = var.asg_max <= 4
    error_message = "max_size limite a 4 (quota vCPU du compte academique)."
  }
}

variable "cpu_target" {
  description = "CPU moyen cible (%) de la politique de scaling"
  type        = number
  default     = 50
}

variable "app_port" {
  type    = number
  default = 80
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "public_key" {
  description = "Cle publique SSH (contenu) deposee sur bastion et instances"
  type        = string
}

variable "instance_profile_name" {
  description = "Profil fourni par AWS Academy (jamais cree par Terraform)"
  type        = string
  default     = "LabInstanceProfile"
}
