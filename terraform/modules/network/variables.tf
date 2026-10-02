# Entrees du module reseau : tout ce qui differe entre staging et prod est
# un parametre (aucun nom, CIDR ou nombre d'AZ code en dur dans le module).

variable "name_prefix" {
  description = "Prefixe des noms de ressources, ex. neocargo-staging"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC (/16 attendu : decoupe en /24 par couche)"
  type        = string
}

variable "az_count" {
  description = "Nombre de zones de disponibilite couvertes par chaque couche"
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 2
    error_message = "Au moins 2 AZ : exige par l'ALB et le groupe de sous-reseaux RDS."
  }
}

variable "admin_cidr" {
  description = "IP de l'administrateur autorisee en SSH sur le bastion (/32)"
  type        = string
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/32$", var.admin_cidr))
    error_message = "admin_cidr doit etre une IP unique en /32."
  }
}

variable "app_port" {
  description = "Port HTTP expose par les instances applicatives"
  type        = number
  default     = 80
}

variable "db_port" {
  description = "Port du moteur de base de donnees"
  type        = number
  default     = 3306
}

variable "monitoring_port" {
  description = "Port de l'agent de supervision (node_exporter)"
  type        = number
  default     = 9100
}
