-- Carrega os CSVs mais recentes da camada silver (sales/reviews) para as tabelas RAW.
-- Idempotente por natureza do COPY INTO (Snowflake ignora arquivos ja carregados, a menos
-- que FORCE = TRUE seja usado para reprocessamento).

USE DATABASE ${SNOWFLAKE_DATABASE};
USE SCHEMA RAW;

COPY INTO SALES
    FROM @SILVER_STAGE/sales/
    PATTERN = '.*sales\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';

COPY INTO REVIEWS
    FROM @SILVER_STAGE/reviews/
    PATTERN = '.*reviews\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';
