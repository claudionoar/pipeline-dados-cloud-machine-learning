-- Predições do conjunto de teste (hard-code vs. sklearn) prontas para o dashboard e para a
-- análise de acertos/erros pedida na avaliação qualitativa (docs/avaliacao.md).

with predictions as (
    select * from {{ ref('stg_ml_predictions') }}
),

dim_product as (
    select * from {{ ref('dim_product') }}
)

select
    predictions.review_id,
    predictions.product_id,
    predictions.true_label,
    predictions.predicted_label_hardcode,
    predictions.predicted_label_sklearn,
    predictions.model_version,
    predictions.predicted_at,
    (predictions.true_label = predictions.predicted_label_hardcode) as hardcode_correct,
    (predictions.true_label = predictions.predicted_label_sklearn) as sklearn_correct,
    dim_product.category_root,
    dim_product.product_name
from predictions
left join dim_product on predictions.product_id = dim_product.product_id
