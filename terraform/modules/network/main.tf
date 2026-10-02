# ===========================================================================
# Module RESEAU : VPC trois couches (public / applicatif / donnees) sur N AZ,
# routage cloisonne par couche et Security Groups en cascade.
# Instancie a l'identique par staging et prod, seuls les parametres changent.
# ===========================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # AZ choisies dynamiquement : le module reste valable dans toute region.
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# VPC dedie a un environnement : staging et prod ne partagent aucun reseau,
# une erreur sur l'un ne peut donc pas impacter l'autre.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # requis pour resoudre l'endpoint RDS
  tags                 = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

# ---- Sous-reseaux : troisieme octet = couche (0-9 public, 10-19 app, 20-29 data)
# Seule la couche publique attribue des IP publiques.
resource "aws_subnet" "public" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.name_prefix}-public-${count.index}", Tier = "public" }
}

resource "aws_subnet" "app" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10 + count.index)
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.name_prefix}-app-${count.index}", Tier = "app" }
}

resource "aws_subnet" "data" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20 + count.index)
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.name_prefix}-data-${count.index}", Tier = "data" }
}

# ---- Sortie Internet de la couche applicative (paquets) via une NAT unique :
# compromis cout/disponibilite assume pour un compte academique.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.name_prefix}-nat-eip" }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.name_prefix}-nat" }
  depends_on    = [aws_internet_gateway.this]
}

# ---- Routage : une table par couche, pour un cloisonnement explicite et auditable
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.name_prefix}-rt-public" }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = { Name = "${var.name_prefix}-rt-app" }
}

resource "aws_route_table_association" "app" {
  count          = var.az_count
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

# Donnees : aucune route par defaut, la base ne sort jamais vers Internet.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name_prefix}-rt-data" }
}

resource "aws_route_table_association" "data" {
  count          = var.az_count
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}
