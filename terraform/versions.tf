terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Credenciais e regiao vem das variaveis de ambiente padrao do provider AWS
# (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION), ja presentes no .env
# da raiz do projeto - nao ha nada de credencial hardcoded aqui.
provider "aws" {
  region = var.aws_region
}
