# aws/terraform/ — Provisionamento do bucket S3 (Infra como código)

## Provisionamento (passo único, antes de subir o `docker-compose up`)

Igual ao setup do Snowflake (`snowflake/README.md`), este é um passo de infraestrutura rodado
**uma vez**, fora do DAG do Airflow — o pipeline de dados assume que o bucket já existe.

```bash
cd aws/terraform
cp terraform.tfvars.example terraform.tfvars   # ajuste bucket_name (mesmo valor de AWS_S3_BUCKET no .env)

# usando o wrapper (Linux/macOS/git-bash):
chmod +x tf.sh
./tf.sh init
./tf.sh plan
./tf.sh apply
```

Ou diretamente com `docker run` (funciona igual no PowerShell, trocando `$(pwd)` por `${PWD}`):

```bash
docker run --rm -it -v "$(pwd):/workspace" -w /workspace --env-file ../../.env \
  hashicorp/terraform:1.9 init

docker run --rm -it -v "$(pwd):/workspace" -w /workspace --env-file ../../.env \
  hashicorp/terraform:1.9 apply
```

As credenciais AWS vêm do `.env` da raiz (`--env-file ../../.env`) via as variáveis padrão do
provider (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`) — nenhuma
credencial fica no código Terraform.

## Estado (state)

`terraform.tfstate` é gravado localmente em `aws/terraform/` (bind mount do container para o
host, então persiste entre execuções). Fica fora do controle de versão (`.gitignore`) por
conter potencialmente metadados sensíveis do bucket. Para uso em equipe, o próximo passo
natural seria migrar para um backend remoto (ex.: outro bucket S3 + DynamoDB para lock) —
não feito aqui para manter o escopo simples, mencionado como melhoria futura em
`docs/avaliacao.md`.

## Destruir os recursos

```bash
./tf.sh destroy
```

## Troubleshooting

### `Error: No valid credential sources found` / erro do EC2 IMDS

Significa que o provider AWS não recebeu `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` dentro
do container. Causas mais comuns, em ordem de probabilidade:

1. **Nome de variável errado** — variáveis de ambiente são *case-sensitive*. O `.env` precisa
   ter exatamente `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` (maiúsculo), não
   `aws_access_key_id`. `./tf.sh` já valida isso antes de chamar o Terraform e avisa se
   estiver errado.
2. **`.env` não existe ou está vazio** — confirme que existe um `.env` na **raiz do
   projeto** (não só o `.env.example`) e que as duas linhas têm valor depois do `=`.
3. **Credenciais temporárias (SSO/STS)** — se sua credencial veio de um login federado/SSO,
   ela inclui um `AWS_SESSION_TOKEN` além do access key + secret key. As três variáveis
   precisam estar no `.env` (ver `.env.example`); faltando o token, a autenticação falha do
   mesmo jeito mesmo com access key/secret key corretos.

Para depurar sem expor os valores, confirme que as variáveis chegam ao container:

```bash
docker run --rm --env-file ../../.env alpine sh -c 'echo "access_key_len=${#AWS_ACCESS_KEY_ID} secret_len=${#AWS_SECRET_ACCESS_KEY}"'
```

Se os tamanhos aparecerem como `0`, o `.env` não está sendo lido corretamente (passo 1 ou 2
acima).

## Recursos criados

| Recurso | Observação |
|---|---|
| `aws_s3_bucket.data_lake` | criação idempotente do bucket |
| `aws_s3_bucket_versioning` | `put_bucket_versioning` |
| `aws_s3_bucket_server_side_encryption_configuration` | `put_bucket_encryption` |
| `aws_s3_bucket_public_access_block` | `put_public_access_block` |
| `aws_s3_object.layers` (for_each bronze/silver/gold) | `ensure_layer_prefixes` |
