# Racine d'un environnement : state LOCAL propre a ce dossier (isolation
# complete entre staging et prod, voir le rapport : dossiers vs workspaces).
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
  }
}

# Tags communs a toutes les ressources de l'environnement : tracabilite,
# nettoyage et ciblage par l'inventaire Ansible.
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
