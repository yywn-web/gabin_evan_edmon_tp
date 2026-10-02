# ===========================================================================
# Security Groups en cascade : chaque SG interne n'accepte QUE le SG
# immediatement en amont (jamais un CIDR large) :
#   Internet -> ALB -> app -> RDS   et   admin -> bastion -> app (SSH, metriques)
# Regles en ressources separees : les SG se referencent mutuellement, des
# blocs inline creeraient une dependance circulaire.
# ===========================================================================

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-sg-alb"
  description = "ALB public - HTTP depuis Internet uniquement"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name_prefix}-sg-alb" }
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-sg-app"
  description = "Instances applicatives - HTTP depuis ALB, SSH et metriques depuis bastion"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name_prefix}-sg-app" }
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-sg-rds"
  description = "RDS - port base de donnees depuis le SG applicatif uniquement"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name_prefix}-sg-rds" }
}

resource "aws_security_group" "bastion" {
  name        = "${var.name_prefix}-sg-bastion"
  description = "Bastion - SSH depuis l IP admin uniquement"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${var.name_prefix}-sg-bastion" }
}

# ---- ALB : seul flux entrant ouvert a Internet
resource "aws_vpc_security_group_ingress_rule" "alb_http_in" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP public vers le point d entree unique"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Trafic et health checks vers les instances"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

# ---- Applicatif
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP uniquement depuis le SG ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_bastion" {
  security_group_id            = aws_security_group.app.id
  description                  = "SSH Ansible uniquement depuis le SG bastion"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

# Metriques node_exporter lisibles uniquement depuis le bastion (jamais Internet).
resource "aws_vpc_security_group_ingress_rule" "app_metrics_from_bastion" {
  security_group_id            = aws_security_group.app.id
  description                  = "Metriques de supervision depuis le SG bastion"
  ip_protocol                  = "tcp"
  from_port                    = var.monitoring_port
  to_port                      = var.monitoring_port
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_rds" {
  security_group_id            = aws_security_group.app.id
  description                  = "Base de donnees vers le SG RDS uniquement"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.rds.id
}

# Sorties via la NAT : depots de paquets et API S3 (flux sortants uniquement).
resource "aws_vpc_security_group_egress_rule" "app_http_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP sortant via NAT pour les depots"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_https_out" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS sortant via NAT pour depots et S3"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# ---- RDS : une seule regle, aucune sortie
resource "aws_vpc_security_group_ingress_rule" "rds_from_app" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Base de donnees uniquement depuis le SG applicatif"
  ip_protocol                  = "tcp"
  from_port                    = var.db_port
  to_port                      = var.db_port
  referenced_security_group_id = aws_security_group.app.id
}

# ---- Bastion
resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_admin" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH depuis l IP de l administrateur uniquement"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_egress_rule" "bastion_ssh_to_app" {
  security_group_id            = aws_security_group.bastion.id
  description                  = "Rebond SSH vers les instances"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "bastion_metrics_to_app" {
  security_group_id            = aws_security_group.bastion.id
  description                  = "Lecture des metriques des instances"
  ip_protocol                  = "tcp"
  from_port                    = var.monitoring_port
  to_port                      = var.monitoring_port
  referenced_security_group_id = aws_security_group.app.id
}
