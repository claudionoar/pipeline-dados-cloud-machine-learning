variable "bucket_name" {
  description = "Nome do bucket S3 (globalmente unico na AWS). Ver AWS_S3_BUCKET no .env da raiz."
  type        = string
}

variable "aws_region" {
  description = "Regiao AWS. Ver AWS_DEFAULT_REGION no .env da raiz."
  type        = string
  default     = "us-east-1"
}

variable "layer_prefixes" {
  description = "Camadas (medalhao) criadas como pastas dentro do bucket."
  type        = set(string)
  default     = ["bronze/", "silver/", "gold/"]
}
