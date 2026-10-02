# NeoCargo Analytics — TrackFleet : plateforme multi-environnements

Infrastructure AWS trois-tiers (ALB + ASG, RDS, S3) décrite par **3 modules Terraform**
réutilisés par **deux environnements isolés** (`staging`, `prod`), et configurée par
**Ansible en rôles** avec un inventaire dynamique EC2.

## Structure

terraform/
modules/network/ VPC 3 couches, routage par couche, Security Groups en cascade
modules/compute/ ALB, Target Group, Launch Template, ASG + scaling CPU, bastion
modules/data/ RDS MySQL privée, bucket S3 (versioning, SSE, accès public bloqué)
environments/
staging/ main.tf (appelle les 3 modules) + staging.tfvars + state local
prod/ main.tf identique + prod.tfvars + state local
ansible/
roles/common/ socle système, durcissement SSH
roles/webserver/ Nginx + PHP-FPM, page de test connectée à RDS
roles/monitoring/ node_exporter + sonde HTTP (collecteur textfile)
inventory/aws_ec2.yml inventaire dynamique -> groupes staging / prod
group_vars/staging.yml, prod.yml variables différenciées par environnement
site.yml, run_playbook.sh
.github/workflows/ci.yml BONUS : fmt / validate / plan / ansible-lint sur chaque PR
docs/ schéma, rapport d'équipe


## Staging vs prod

| Paramètre | staging | prod |
|---|---|---|
| CIDR VPC | 10.50.0.0/16 | 10.60.0.0/16 |
| ASG min / désiré / max | 1 / 1 / 2 | 2 / 2 / 4 |
| Cible CPU du scaling | 60 % | 50 % |
| RDS | db.t3.micro, sans sauvegarde | db.t3.micro, sauvegardes 7 j |
| Rétention des versions S3 | 7 j | 90 j |
| Logs Nginx / page debug | `info` / oui | `warn` / non |
| Sonde de supervision | chaque minute | toutes les 5 min |

## Déployer un environnement

```bash
cd terraform/environments/staging                     # ou prod
cp secrets.auto.tfvars.example secrets.auto.tfvars    # admin_cidr + db_password
terraform init
terraform plan -var-file=staging.tfvars -out=tfplan
terraform apply tfplan

cd ../../../ansible
./run_playbook.sh staging --syntax-check
./run_playbook.sh staging --check --diff
./run_playbook.sh staging                             # puis une 2e fois : changed=0
```

## Règles de contribution

- `main` est protégée : aucun push direct, PR obligatoire, **1 approbation** d'un autre membre.
- Une branche **par fonctionnalité** : `feat/<scope>-<sujet>`, `fix/...`, `docs/...`, `ci/...`.
- Commits conventionnels : `type(scope): description`.
- Chaque PR décrit **ce qui change** et **pourquoi** ; la revue comporte au moins un commentaire argumenté.
- Aucune branche ni PR supprimée après merge.

## Secrets — jamais versionnés

`secrets.auto.tfvars`, `*.tfstate`, `.terraform/`, `ansible/.vault_pass`, `ansible/generated/`.
Les fichiers `<env>.tfvars` sont versionnés : ils ne contiennent que du dimensionnement.
