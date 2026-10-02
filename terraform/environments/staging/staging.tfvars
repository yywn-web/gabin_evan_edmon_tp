# STAGING : environnement "jetable" de test avant production.
# Dimensionnement minimal, retention courte, reseau distinct de prod.
environment = "staging"
vpc_cidr    = "10.50.0.0/16"

instance_type = "t3.micro"
asg_min       = 1
asg_desired   = 1
asg_max       = 2
cpu_target    = 60 # moins reactif : pas d'enjeu de service en staging

db_instance_class        = "db.t3.micro"
db_backup_retention_days = 0 # environnement recreable, pas de sauvegarde

s3_noncurrent_retention_days = 7
