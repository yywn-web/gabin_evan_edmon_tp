# Interface du module donnees (jamais le mot de passe).

output "rds_address" {
  value = aws_db_instance.this.address
}

output "rds_endpoint" {
  value = aws_db_instance.this.endpoint
}

output "bucket_name" {
  value = terraform_data.bucket.output.name
}
