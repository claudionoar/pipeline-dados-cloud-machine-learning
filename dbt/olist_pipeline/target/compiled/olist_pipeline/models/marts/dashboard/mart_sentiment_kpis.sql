-- Fatos agregados para o dashboard Metabase: indicadores de sentimento por categoria de
-- produto. Cada review está ligada a um pedido (não diretamente a um produto); usa-se o
-- produto do primeiro item do pedido para evitar duplicar a review entre categorias em
-- pedidos com vários itens de categorias diferentes (mesma simplificação documentada em
-- mart_late_delivery_features para o vendedor "primário").

-- CTE que carrega todas as avaliações da tabela fato fact_reviews
WITH reviews AS (
    SELECT * FROM PROJETO_OLIST_DB.ANALYTICS.fact_reviews
),

-- CTE que seleciona apenas o primeiro item de cada pedido (menor order_item_id)
-- para associar a review a um único produto/categoria
primary_item AS (
    SELECT order_id, product_key
    FROM PROJETO_OLIST_DB.ANALYTICS.fact_order_items
    QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_item_id) = 1
),

-- CTE que carrega a dimensão de produtos (para obter a categoria em inglês)
products AS (
    SELECT * FROM PROJETO_OLIST_DB.ANALYTICS.dim_products
)

-- Seleção final: agrega os KPIs de sentimento por categoria de produto
SELECT
    products.category_name_english,                     -- categoria do produto (em inglês) como dimensão de agrupamento
    COUNT(reviews.review_key) AS review_count,          -- total de avaliações na categoria
    AVG(reviews.review_score) AS avg_review_score,      -- nota média das avaliações na categoria
    -- Proporção de avaliações positivas (nullif evita divisão por zero)
    SUM(CASE WHEN reviews.sentiment_label = 'positivo' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(reviews.review_key), 0)::FLOAT AS pct_positivo,
    -- Proporção de avaliações neutras
    SUM(CASE WHEN reviews.sentiment_label = 'neutro' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(reviews.review_key), 0)::FLOAT AS pct_neutro,
    -- Proporção de avaliações negativas
    SUM(CASE WHEN reviews.sentiment_label = 'negativo' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(reviews.review_key), 0)::FLOAT AS pct_negativo
FROM reviews
-- LEFT JOIN traz o produto do primeiro item de cada pedido avaliado
LEFT JOIN primary_item ON reviews.order_id = primary_item.order_id
-- LEFT JOIN traz os atributos do produto (categoria)
LEFT JOIN products ON primary_item.product_key = products.product_key
GROUP BY products.category_name_english                 -- uma linha por categoria de produto