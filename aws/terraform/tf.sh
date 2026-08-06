#!/usr/bin/env bash
# Wrapper para rodar o Terraform via Docker, sem instalar nada na maquina.
# Uso: ./tf.sh init | ./tf.sh plan | ./tf.sh apply | ./tf.sh destroy
set -euo pipefail
cd "$(dirname "$0")"

ENV_FILE="../.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Erro: $ENV_FILE não encontrado." >&2
  echo "Rode 'cp .env.example .env' na raiz do projeto e preencha as credenciais AWS antes de continuar." >&2
  exit 1
fi

# Checagem preventiva do erro mais comum: nomes de variavel errados (case-sensitive) ou
# credenciais ainda em branco - falha aqui com uma mensagem clara em vez de deixar o
# Terraform/AWS SDK falhar la na frente com "No valid credential sources found".
if ! grep -qE '^AWS_ACCESS_KEY_ID=.+' "$ENV_FILE" || ! grep -qE '^AWS_SECRET_ACCESS_KEY=.+' "$ENV_FILE"; then
  echo "Erro: AWS_ACCESS_KEY_ID e/ou AWS_SECRET_ACCESS_KEY não estão preenchidos em $ENV_FILE." >&2
  echo "Lembrete: os nomes das variáveis são case-sensitive (precisa ser MAIÚSCULO, ex.: AWS_ACCESS_KEY_ID, não aws_access_key_id)." >&2
  exit 1
fi

docker run --rm -it \
  -v "$(pwd):/workspace" \
  -w /workspace \
  --env-file "$ENV_FILE" \
  hashicorp/terraform:1.9 "$@"
