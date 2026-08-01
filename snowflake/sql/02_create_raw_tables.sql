-- Tabelas RAW no esquema canonico produzido por s3/processing.py (camada silver).

USE DATABASE ${SNOWFLAKE_DATABASE};
USE SCHEMA RAW;

-- Ordem das colunas precisa bater exatamente com a ordem de saida de s3/processing.py
-- (COPY INTO sem MATCH_BY_COLUMN_NAME mapeia por posicao, nao por nome).
--
-- CREATE OR REPLACE (nao IF NOT EXISTS): se a ordem das colunas mudar depois, IF NOT EXISTS
-- deixaria a tabela ja existente com o esquema antigo, causando desalinhamento silencioso entre
-- posicao do CSV e coluna da tabela no COPY INTO (foi o que quebrou o load_snowflake_raw em
-- 2026-08-01). Seguro recriar porque estas tabelas RAW sao truncadas e recarregadas do zero em
-- toda execucao (ver 03_copy_into.sql).
CREATE OR REPLACE TABLE SALES (
    product_id           VARCHAR,
    product_name         VARCHAR,
    category             VARCHAR,
    discounted_price      FLOAT,
    actual_price          FLOAT,
    discount_percentage   FLOAT,
    rating                FLOAT,
    rating_count          NUMBER,
    about_product         VARCHAR,
    img_link              VARCHAR,
    product_link          VARCHAR,
    category_root        VARCHAR,
    ingested_at            TIMESTAMP_TZ
)
COMMENT = 'Catalogo de produtos (dados estruturados) - carregado via COPY INTO da camada silver';

CREATE OR REPLACE TABLE REVIEWS (
    review_id           VARCHAR,
    product_id          VARCHAR,
    user_id             VARCHAR,
    review_title        VARCHAR,
    review_text         VARCHAR,
    rating               NUMBER,
    review_date          TIMESTAMP_TZ,
    word_count            NUMBER,
    char_count            NUMBER,
    exclamation_count     NUMBER,
    sentiment_label      VARCHAR,
    ingested_at           TIMESTAMP_TZ
)
COMMENT = 'Reviews de texto (dados nao estruturados) com rotulo de sentimento derivado do rating';

CREATE OR REPLACE TABLE ML_PREDICTIONS (
    review_id                  VARCHAR,
    product_id                 VARCHAR,
    true_label                 VARCHAR,
    predicted_label_hardcode   VARCHAR,
    predicted_label_sklearn    VARCHAR,
    model_version                VARCHAR,
    predicted_at                 TIMESTAMP_TZ
)
COMMENT = 'Predicoes de sentimento do conjunto de teste, geradas pelo modulo machine-learning/';
