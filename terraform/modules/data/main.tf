# ===========================================================================
# Module DONNEES : base RDS privee et bucket S3 securise pour un environnement.
# ===========================================================================

# ---------------- RDS ----------------
# Groupe de sous-reseaux "donnees" sur >= 2 AZ (exige par RDS).
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.data_subnet_ids
}

# Base managee, jamais publique ; seuls dimensionnement et retention varient
# entre staging (jetable) et prod (reference).
resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-mysql"
  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.rds_sg_id]
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  backup_retention_period    = var.db_backup_retention_days
  auto_minor_version_upgrade = true
  apply_immediately          = true

  # Environnements academiques detruits en fin de TP.
  skip_final_snapshot = true
  deletion_protection = false
}

# ---------------- S3 ----------------
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.name_prefix}-backups-${random_id.bucket_suffix.hex}"
  bucket_arn  = "arn:aws:s3:::${local.bucket_name}"
}

# Contournement documente d'AWS Academy : une SCP refuse
# s3:GetBucketObjectLockConfiguration, appele par aws_s3_bucket a chaque
# lecture. Seule la CREATION passe par l'AWS CLI (idempotente via head-bucket) ;
# toute la configuration de securite reste en ressources natives ci-dessous.
# Le chemin du script est porte par l'input car un provisioner de destruction
# ne peut referencer que self.
resource "terraform_data" "bucket" {
  input = {
    name   = local.bucket_name
    script = "${path.module}/scripts/delete_bucket.sh"
  }

  provisioner "local-exec" {
    command = "aws s3api head-bucket --bucket ${self.input.name} 2>/dev/null || aws s3api create-bucket --bucket ${self.input.name} --region ${var.region}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash ${self.input.script} ${self.input.name}"
  }
}

# ACL desactivees : impossible de rendre un objet public par ACL.
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = terraform_data.bucket.output.name
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = terraform_data.bucket.output.name
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = terraform_data.bucket.output.name
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = terraform_data.bucket.output.name
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Retention differenciee par environnement (courte en staging, longue en prod).
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = terraform_data.bucket.output.name
  rule {
    id     = "retention-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = var.s3_noncurrent_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
  depends_on = [aws_s3_bucket_versioning.this]
}

# Refus explicites : principal hors compte (anonyme compris) et HTTP non chiffre.
data "aws_iam_policy_document" "bucket" {
  statement {
    sid       = "DenyOutsideAccount"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [local.bucket_arn, "${local.bucket_arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [local.bucket_arn, "${local.bucket_arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket     = terraform_data.bucket.output.name
  policy     = data.aws_iam_policy_document.bucket.json
  depends_on = [aws_s3_bucket_public_access_block.this]
}
