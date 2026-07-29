-- Carrega os CSVs mais recentes da camada silver (sales/reviews) para as tabelas RAW.
--
-- TRUNCATE antes de cada COPY INTO: a tabela RAW representa o snapshot mais recente
-- processado (s3/processing.py sempre reprocessa tudo, nao incrementalmente), nao um log que
-- acumula historico. Sem o TRUNCATE, o COPY INTO recarrega o arquivo inteiro toda vez que o
-- pipeline roda de novo (o campo ingested_at muda a cada reprocessamento, entao o hash do
-- arquivo muda e o "ja carregado antes" do Snowflake nunca bate), duplicando as linhas a
-- cada execucao.

USE DATABASE ${SNOWFLAKE_DATABASE};
USE SCHEMA RAW;

TRUNCATE TABLE IF EXISTS SALES;

COPY INTO SALES
    FROM @SILVER_STAGE/sales/
    PATTERN = '.*sales\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';

TRUNCATE TABLE IF EXISTS REVIEWS;

COPY INTO REVIEWS
    FROM @SILVER_STAGE/reviews/
    PATTERN = '.*reviews\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';
