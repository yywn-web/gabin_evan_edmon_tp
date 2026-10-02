#!/bin/bash
# Amorcage minimal execute par cloud-init au 1er boot : nginx + /health, pour
# que l'instance passe "healthy" avant le passage d'Ansible. Sans lui, l'ASG
# (health_check_type = ELB) remplacerait les instances en boucle.
set -euxo pipefail
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
echo "OK" > /var/www/html/health
systemctl enable --now nginx
