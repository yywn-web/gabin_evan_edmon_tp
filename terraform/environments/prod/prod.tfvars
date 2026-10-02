# PROD : environnement de reference. Haute disponibilite (2 instances minimum,
# une par AZ), sauvegardes RDS et retention longue.
environment = "prod"
vpc_cidr    = "10.60.0.0/16"

instance_type = "t3.micro"
asg_min       = 2
asg_desired   = 2
asg_max       = 4 # plafond du quota academique
cpu_target    = 50

db_instance_class        = "db.t3.micro" # quota academique (db.t3.small+ en vraie prod)
db_backup_retention_days = 7

s3_noncurrent_retention_days = 90
