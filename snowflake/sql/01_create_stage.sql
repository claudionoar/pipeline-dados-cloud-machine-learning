-- External stage apontando para a camada "silver" do bucket S3.
--
-- Usa CREDENTIALS diretas (AWS_KEY_ID/AWS_SECRET_KEY/AWS_TOKEN) em vez de STORAGE INTEGRATION:
-- storage integration exige criar uma IAM Role na AWS (iam:CreateRole), permissão que contas
-- de laboratório (ex.: AWS Academy Learner Lab) tipicamente bloqueiam para o aluno. Com
-- credenciais temporarias de sessao (AWS_SESSION_TOKEN preenchido no .env), o AWS_TOKEN abaixo
-- e obrigatorio; se um dia trocar para um usuario IAM permanente (sem sessao temporaria),
-- remova a linha AWS_TOKEN. Ver docs/arquitetura.md para a limitacao documentada.
--
-- Efeito colateral: como as credenciais do lab expiram (poucas horas), este stage para de
-- funcionar quando elas vencem - rode este step de novo (com o .env atualizado) para renovar.

USE DATABASE ${SNOWFLAKE_DATABASE};
USE SCHEMA RAW;

CREATE FILE FORMAT IF NOT EXISTS CSV_STANDARD
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'NaN', '<NA>')
    EMPTY_FIELD_AS_NULL = TRUE;

CREATE OR REPLACE STAGE SILVER_STAGE
    URL = 's3://${AWS_S3_BUCKET}/silver/'
    CREDENTIALS = (AWS_KEY_ID = '${AWS_ACCESS_KEY_ID}' AWS_SECRET_KEY = '${AWS_SECRET_ACCESS_KEY}' AWS_TOKEN = '${AWS_SESSION_TOKEN}')
    FILE_FORMAT = CSV_STANDARD
    COMMENT = 'Aponta para a camada silver (dados normalizados) do bucket S3 - credenciais temporarias, renovar quando expirar';
