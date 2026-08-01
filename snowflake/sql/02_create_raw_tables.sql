-- Tabelas RAW no esquema canonico produzido por s3/processing.py (camada silver) a partir do
-- dataset Olist Brazilian E-Commerce (9 tabelas + tradução de categoria).
--
-- Ordem das colunas precisa bater exatamente com a ordem de saida de s3/processing.py
-- (COPY INTO sem MATCH_BY_COLUMN_NAME mapeia por posicao, nao por nome).
--
-- CREATE OR REPLACE (nao IF NOT EXISTS): estas tabelas RAW sao truncadas e recarregadas do
-- zero em toda execucao (ver 03_copy_into.sql), entao e seguro recriar caso o esquema mude.

USE DATABASE ${SNOWFLAKE_DATABASE};
USE SCHEMA RAW;

CREATE OR REPLACE TABLE CUSTOMERS (
    customer_id                VARCHAR,
    customer_unique_id         VARCHAR,
    customer_zip_code_prefix   VARCHAR,
    customer_city              VARCHAR,
    customer_state             VARCHAR
)
COMMENT = 'Um customer_id por pedido (customer_unique_id identifica a pessoa entre pedidos).';

CREATE OR REPLACE TABLE GEOLOCATION (
    geolocation_zip_code_prefix   VARCHAR,
    geolocation_lat                FLOAT,
    geolocation_lng                FLOAT,
    geolocation_city               VARCHAR,
    geolocation_state              VARCHAR
)
COMMENT = 'Lat/lng por prefixo de CEP (varias linhas por prefixo) - agregada em dim_geolocation.';

CREATE OR REPLACE TABLE ORDERS (
    order_id                          VARCHAR,
    customer_id                        VARCHAR,
    order_status                       VARCHAR,
    order_purchase_timestamp           TIMESTAMP_NTZ,
    order_approved_at                  TIMESTAMP_NTZ,
    order_delivered_carrier_date       TIMESTAMP_NTZ,
    order_delivered_customer_date      TIMESTAMP_NTZ,
    order_estimated_delivery_date      TIMESTAMP_NTZ
)
COMMENT = 'Grao: order_id. Base para a feature de atraso na entrega (is_late).';

CREATE OR REPLACE TABLE ORDER_ITEMS (
    order_id                VARCHAR,
    order_item_id            NUMBER,
    product_id                VARCHAR,
    seller_id                 VARCHAR,
    shipping_limit_date       TIMESTAMP_NTZ,
    price                      FLOAT,
    freight_value              FLOAT
)
COMMENT = 'Grao: order_id + order_item_id (um pedido pode ter varios itens/vendedores).';

CREATE OR REPLACE TABLE ORDER_PAYMENTS (
    order_id                VARCHAR,
    payment_sequential        NUMBER,
    payment_type               VARCHAR,
    payment_installments        NUMBER,
    payment_value                 FLOAT
)
COMMENT = 'Grao: order_id + payment_sequential (um pedido pode ter varios pagamentos).';

CREATE OR REPLACE TABLE ORDER_REVIEWS (
    review_id                  VARCHAR,
    order_id                    VARCHAR,
    review_score                  NUMBER,
    review_comment_title            VARCHAR,
    review_comment_message           VARCHAR,
    review_creation_date               TIMESTAMP_NTZ,
    review_answer_timestamp             TIMESTAMP_NTZ
)
COMMENT = 'Grao: review_id. review_comment_message vazio em ~59% das linhas (limitacao documentada).';

CREATE OR REPLACE TABLE PRODUCTS (
    product_id                     VARCHAR,
    product_category_name            VARCHAR,
    product_name_lenght                 FLOAT,
    product_description_lenght           FLOAT,
    product_photos_qty                    FLOAT,
    product_weight_g                       FLOAT,
    product_length_cm                       FLOAT,
    product_height_cm                        FLOAT,
    product_width_cm                          FLOAT
)
COMMENT = 'Grao: product_id. product_category_name em portugues - traduzido via CATEGORY_TRANSLATION.';

CREATE OR REPLACE TABLE SELLERS (
    seller_id                 VARCHAR,
    seller_zip_code_prefix      VARCHAR,
    seller_city                   VARCHAR,
    seller_state                    VARCHAR
)
COMMENT = 'Grao: seller_id.';

CREATE OR REPLACE TABLE CATEGORY_TRANSLATION (
    product_category_name            VARCHAR,
    product_category_name_english      VARCHAR
)
COMMENT = 'Traducao pt->en do nome de categoria de produto.';

CREATE OR REPLACE TABLE ML_PREDICTIONS (
    order_id                   VARCHAR,
    true_label                   VARCHAR,
    predicted_label_hardcode       VARCHAR,
    predicted_label_sklearn          VARCHAR,
    model_version                      VARCHAR,
    predicted_at                         TIMESTAMP_TZ
)
COMMENT = 'Predicoes de atraso na entrega (on_time/late) do conjunto de teste, geradas por machine-learning/.';
