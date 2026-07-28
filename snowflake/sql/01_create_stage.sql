-- Storage integration + external stage apontando para a camada "silver" do bucket S3.
-- Depois de rodar o CREATE STORAGE INTEGRATION, rode:
--     DESC INTEGRATION ${SNOWFLAKE_STORAGE_INTEGRATION};
-- e copie STORAGE_AWS_IAM_USER_ARN / STORAGE_AWS_EXTERNAL_ID para o trust policy da IAM Role
-- referenciada em STORAGE_AWS_ROLE_ARN (documentação: docs/dicionario_dados.md e
-- https://docs.snowflake.com/en/user-guide/data-load-s3-config-storage-integration).

USE DATABASE ${SNOWFLAKE_DATABASE};
USE SCHEMA RAW;

CREATE STORAGE INTEGRATION IF NOT EXISTS ${SNOWFLAKE_STORAGE_INTEGRATION}
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = '${SNOWFLAKE_S3_ROLE_ARN}'
    STORAGE_ALLOWED_LOCATIONS = ('s3://${AWS_S3_BUCKET}/silver/');

CREATE FILE FORMAT IF NOT EXISTS CSV_STANDARD
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL', 'NaN')
    EMPTY_FIELD_AS_NULL = TRUE;

CREATE STAGE IF NOT EXISTS SILVER_STAGE
    STORAGE_INTEGRATION = ${SNOWFLAKE_STORAGE_INTEGRATION}
    URL = 's3://${AWS_S3_BUCKET}/silver/'
    FILE_FORMAT = CSV_STANDARD
    COMMENT = 'Aponta para a camada silver (dados normalizados) do bucket S3';
