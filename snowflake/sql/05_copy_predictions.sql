-- Carrega as predicoes de ML (geradas depois do dbt run, ao final do DAG) para RAW.ML_PREDICTIONS.

USE DATABASE ${SNOWFLAKE_DATABASE};
USE SCHEMA RAW;

COPY INTO ML_PREDICTIONS
    FROM @SILVER_STAGE/ml_predictions/
    PATTERN = '.*predictions\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';
