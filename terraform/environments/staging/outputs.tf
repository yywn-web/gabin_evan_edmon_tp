# Sorties consommees par l'equipe (tests) et par ansible/run_playbook.sh.

output "environment" {
  value = var.environment
}

output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "alb_url" {
  value = "http://${module.compute.alb_dns_name}/"
}

output "bastion_public_ip" {
  value = module.compute.bastion_public_ip
}

output "asg_name" {
  value = module.compute.asg_name
}

output "target_group_arn" {
  value = module.compute.target_group_arn
}

output "rds_address" {
  value = module.data.rds_address
}

output "rds_endpoint" {
  value = module.data.rds_endpoint
}

output "bucket_name" {
  value = module.data.bucket_name
}

output "vpc_cidr" {
  value = module.network.vpc_cidr
}
