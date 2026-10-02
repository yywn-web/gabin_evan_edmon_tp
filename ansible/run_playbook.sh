#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Configure UN environnement :  ./run_playbook.sh staging|prod [options ansible]
#   1. lit les outputs Terraform de environments/<env>/ (aucune IP recopiee) ;
#   2. genere le ssh_config du rebond par le bastion de cet environnement ;
#   3. cree le coffre vault/<env>.yml depuis secrets.auto.tfvars si absent
#      (fichier temporaire en RAM, efface ensuite) ;
#   4. lance site.yml limite au groupe de l'environnement.
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

ENV="${1:-}"
case "$ENV" in staging|prod) shift ;; *) echo "Usage : $0 staging|prod [options ansible-playbook]" >&2; exit 1 ;; esac

TF_DIR="../terraform/environments/$ENV"
VAULT_FILE="vault/$ENV.yml"
mkdir -p generated vault

tfo() { terraform -chdir="$TF_DIR" output -raw "$1"; }
BASTION_IP=$(tfo bastion_public_ip)
VPC_PREFIX=$(tfo vpc_cidr | cut -d. -f1-2)

cat > generated/tf_vars_${ENV}.yml <<VARS
---
# Genere depuis terraform output ($ENV) : ne pas editer.
rds_address: "$(tfo rds_address)"
alb_dns_name: "$(tfo alb_dns_name)"
bucket_name: "$(tfo bucket_name)"
VARS

cat > generated/ssh_config <<SSH
Host bastion
    HostName ${BASTION_IP}
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts_neocargo_${ENV}

Host ${VPC_PREFIX}.*
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    ProxyJump bastion
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts_neocargo_${ENV}
SSH

[ -f .vault_pass ] || ( umask 077; openssl rand -base64 32 > .vault_pass; echo "Coffre : .vault_pass genere (non versionne)" )

if [ ! -f "$VAULT_FILE" ]; then
  PW=$(sed -n 's/^[[:space:]]*db_password[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p' "$TF_DIR/secrets.auto.tfvars")
  [ -n "$PW" ] || { echo "db_password introuvable dans $TF_DIR/secrets.auto.tfvars" >&2; exit 1; }
  TMP=$(mktemp -p /dev/shm); chmod 600 "$TMP"
  printf -- '---\nvault_db_password: "%s"\n' "$PW" > "$TMP"; unset PW
  ansible-vault encrypt "$TMP" --output "$VAULT_FILE"
  shred -u "$TMP"
  echo "Coffre chiffre cree : $VAULT_FILE"
fi

ansible-playbook site.yml --limit "$ENV" -e @generated/tf_vars_${ENV}.yml "$@"
