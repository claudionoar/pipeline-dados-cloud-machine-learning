-- Tabela fato de avaliações (fact_reviews)
-- Consome a staging stg_order_reviews e enriquece com a order_key vinda de fact_orders

-- CTE que carrega todos os registros da camada de staging de avaliações
WITH reviews AS (
    SELECT * FROM {{ ref('stg_order_reviews') }}
),

-- CTE que traz apenas as chaves de pedido necessárias para o join
orders AS (
    SELECT order_id, order_key FROM {{ ref('fact_orders') }}
)

-- Grao: review_id + order_id (nao so review_id) - limitacao real do dataset Olist: ~0,8% dos
-- review_id se repetem em order_id diferentes (ver docs/dicionario_dados.md).
-- Seleção final: cria a surrogate key composta e junta a order_key correspondente
SELECT
    {{ dbt_utils.generate_surrogate_key(['reviews.review_id', 'reviews.order_id']) }} AS review_key,  -- chave substituta única (review_id + order_id)
    reviews.review_id,                  -- identificador da avaliação
    reviews.order_id,                   -- identificador do pedido avaliado
    orders.order_key,                   -- chave substituta do pedido (vinda de fact_orders)
    reviews.review_score,               -- nota atribuída na avaliação
    reviews.titulo,                     -- título do comentário da avaliação
    reviews.mensagem,                   -- mensagem/texto da avaliação
    reviews.sentiment_label,            -- rótulo de sentimento derivado do texto
    reviews.review_creation_date,       -- data de criação da avaliação
    reviews.review_answer_timestamp     -- timestamp da resposta à avaliação
FROM reviews
-- LEFT JOIN mantém todas as avaliações, mesmo sem pedido correspondente em fact_orders
LEFT JOIN orders ON reviews.order_id = orders.order_id
