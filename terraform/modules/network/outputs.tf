# Interface du module reseau : consommee par les modules compute et data.

output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  value = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}

# Jeton de dependance : reference par le module compute pour que l'ASG ne
# lance ses instances qu'une fois la NAT ET les routes privees en place
# (l'amorcage user_data a besoin d'Internet des le premier boot).
output "egress_ready" {
  value = join(",", concat([aws_nat_gateway.this.id], aws_route_table_association.app[*].id))
}

output "nat_public_ip" {
  value = aws_eip.nat.public_ip
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "app_sg_id" {
  value = aws_security_group.app.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}
