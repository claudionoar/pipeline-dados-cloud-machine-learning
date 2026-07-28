-- Provisiona warehouse, database e schemas base do projeto.
-- Execute com um role que possa criar objetos (ex.: SYSADMIN).

CREATE WAREHOUSE IF NOT EXISTS ${SNOWFLAKE_WAREHOUSE}
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Warehouse do projeto final - pipeline Amazon Sales & Reviews';

CREATE DATABASE IF NOT EXISTS ${SNOWFLAKE_DATABASE}
    COMMENT = 'Base analitica do projeto final integrado (Modelagem de Dados / ML / Cloud)';

USE DATABASE ${SNOWFLAKE_DATABASE};

CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Dados carregados diretamente do S3 (camada silver), sem transformacao dbt';

CREATE SCHEMA IF NOT EXISTS ANALYTICS
    COMMENT = 'Staging, dimensions, facts e marts materializados pelo dbt';

USE WAREHOUSE ${SNOWFLAKE_WAREHOUSE};
USE SCHEMA ${SNOWFLAKE_DATABASE}.RAW;
