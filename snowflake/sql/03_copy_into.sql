-- Carrega os CSVs mais recentes da camada silver (uma pasta por tabela Olist) para as tabelas
-- RAW correspondentes.
--
-- TRUNCATE antes de cada COPY INTO: a tabela RAW representa o snapshot mais recente processado
-- (s3/processing.py sempre reprocessa tudo, nao incrementalmente), nao um log que acumula
-- historico. Sem o TRUNCATE, o COPY INTO recarrega o arquivo inteiro toda vez que o pipeline
-- roda de novo, duplicando as linhas a cada execucao (mesmo motivo documentado no projeto
-- original: sem particao por data, o "ja carregado antes" do Snowflake nunca bate).

USE DATABASE ${SNOWFLAKE_DATABASE};
USE SCHEMA RAW;

TRUNCATE TABLE IF EXISTS CUSTOMERS;
COPY INTO CUSTOMERS
    FROM @SILVER_STAGE/customers/
    PATTERN = '.*customers\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';

TRUNCATE TABLE IF EXISTS GEOLOCATION;
COPY INTO GEOLOCATION
    FROM @SILVER_STAGE/geolocation/
    PATTERN = '.*geolocation\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';

TRUNCATE TABLE IF EXISTS ORDERS;
COPY INTO ORDERS
    FROM @SILVER_STAGE/orders/
    PATTERN = '.*orders\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';

TRUNCATE TABLE IF EXISTS ORDER_ITEMS;
COPY INTO ORDER_ITEMS
    FROM @SILVER_STAGE/order_items/
    PATTERN = '.*order_items\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';

TRUNCATE TABLE IF EXISTS ORDER_PAYMENTS;
COPY INTO ORDER_PAYMENTS
    FROM @SILVER_STAGE/order_payments/
    PATTERN = '.*order_payments\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';

TRUNCATE TABLE IF EXISTS ORDER_REVIEWS;
COPY INTO ORDER_REVIEWS
    FROM @SILVER_STAGE/order_reviews/
    PATTERN = '.*order_reviews\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';

TRUNCATE TABLE IF EXISTS PRODUCTS;
COPY INTO PRODUCTS
    FROM @SILVER_STAGE/products/
    PATTERN = '.*products\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';

TRUNCATE TABLE IF EXISTS SELLERS;
COPY INTO SELLERS
    FROM @SILVER_STAGE/sellers/
    PATTERN = '.*sellers\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';

TRUNCATE TABLE IF EXISTS CATEGORY_TRANSLATION;
COPY INTO CATEGORY_TRANSLATION
    FROM @SILVER_STAGE/category_translation/
    PATTERN = '.*category_translation\\.csv'
    FILE_FORMAT = (FORMAT_NAME = CSV_STANDARD)
    ON_ERROR = 'ABORT_STATEMENT';
