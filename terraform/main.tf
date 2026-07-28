# Bucket S3 com a mesma organizacao em camadas (bronze/silver/gold) e as mesmas
# configuracoes de seguranca basica que antes eram aplicadas por s3/create_bucket.py
# (agora substituido por este codigo Terraform - ver terraform/README.md).

resource "aws_s3_bucket" "data_lake" {
  bucket = var.bucket_name

  tags = {
    Project = "amazon-pipeline"
  }
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "layers" {
  for_each = var.layer_prefixes

  bucket  = aws_s3_bucket.data_lake.id
  key     = each.value
  content = ""
}