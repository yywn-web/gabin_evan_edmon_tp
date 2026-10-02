# ===========================================================================
# Composition d'un environnement : appelle les TROIS MEMES modules que l'autre
# environnement. Ce fichier est identique dans staging/ et prod/ ; seules les
# valeurs du fichier <env>.tfvars changent.
# ===========================================================================

locals {
  name_prefix = "${var.project}-${var.environment}"
}

module "network" {
  source = "../../modules/network"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  az_count    = var.az_count
  admin_cidr  = var.admin_cidr
}

module "compute" {
  source = "../../modules/compute"

  name_prefix       = local.name_prefix
  project           = var.project
  environment       = var.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  app_subnet_ids    = module.network.app_subnet_ids
  alb_sg_id         = module.network.alb_sg_id
  app_sg_id         = module.network.app_sg_id
  bastion_sg_id     = module.network.bastion_sg_id
  network_ready     = module.network.egress_ready

  instance_type = var.instance_type
  asg_min       = var.asg_min
  asg_desired   = var.asg_desired
  asg_max       = var.asg_max
  cpu_target    = var.cpu_target
  public_key    = file(pathexpand(var.public_key_path))
}

module "data" {
  source = "../../modules/data"

  name_prefix     = local.name_prefix
  region          = var.region
  data_subnet_ids = module.network.data_subnet_ids
  rds_sg_id       = module.network.rds_sg_id

  db_instance_class            = var.db_instance_class
  db_backup_retention_days     = var.db_backup_retention_days
  db_name                      = var.db_name
  db_username                  = var.db_username
  db_password                  = var.db_password
  s3_noncurrent_retention_days = var.s3_noncurrent_retention_days
}
