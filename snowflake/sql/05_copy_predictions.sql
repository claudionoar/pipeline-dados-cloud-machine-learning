-- Carrega as predicoes de atraso na entrega (geradas depois do dbt run, ao final do DAG) para
-- RAW.ML_PREDICTIONS.
-- TRUNCATE antes do COPY INTO pelo mesmo motivo de 03_copy_into.sql: predicted_at muda a cada
-- execucao, entao sem o truncate o Snowflake recarrega (duplica) o arquivo a cada run.

USE DATABASE ${SNOWFLAKE_DATABASE};
USE SCHEMA RAW;

TRUNCATE TABLE IF EXISTS ML_PREDICTIONS;

COPY INTO ML_PREDICTIONS
    FROM @SILVER_STAGE/ml_predictions/
    PATTERN = '.*predictions\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';
