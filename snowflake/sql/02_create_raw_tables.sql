-- Tabelas RAW no esquema canonico produzido por s3/processing.py (camada silver).

USE DATABASE ${SNOWFLAKE_DATABASE};
USE SCHEMA RAW;

CREATE TABLE IF NOT EXISTS SALES (
    product_id           VARCHAR,
    product_name         VARCHAR,
    category             VARCHAR,
    category_root        VARCHAR,
    discounted_price      FLOAT,
    actual_price          FLOAT,
    discount_percentage   FLOAT,
    rating                FLOAT,
    rating_count          NUMBER,
    about_product         VARCHAR,
    img_link              VARCHAR,
    product_link          VARCHAR,
    ingested_at            TIMESTAMP_TZ
)
COMMENT = 'Catalogo de produtos (dados estruturados) - carregado via COPY INTO da camada silver';

CREATE TABLE IF NOT EXISTS REVIEWS (
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

CREATE TABLE IF NOT EXISTS ML_PREDICTIONS (
    review_id                  VARCHAR,
    product_id                 VARCHAR,
    true_label                 VARCHAR,
    predicted_label_hardcode   VARCHAR,
    predicted_label_sklearn    VARCHAR,
    model_version                VARCHAR,
    predicted_at                 TIMESTAMP_TZ
)
COMMENT = 'Predicoes de sentimento do conjunto de teste, geradas pelo modulo machine-learning/';
