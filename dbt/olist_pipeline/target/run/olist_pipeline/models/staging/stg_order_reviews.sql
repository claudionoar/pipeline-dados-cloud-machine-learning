
  create or replace   view PROJETO_OLIST_DB.ANALYTICS.stg_order_reviews
  
   as (
    -- Camada STAGING de raw.order_reviews.
-- As colunas NÃO ESTRUTURADAS são review_comment_title e review_comment_message.
-- Aqui as tratamos e delas derivamos colunas estruturadas, testáveis.
-- Materializado como VIEW: não persiste tabela física.
 
-- 

WITH source AS (
    SELECT * FROM PROJETO_OLIST_DB.RAW.order_reviews
),

limpo AS ( 
    SELECT
        review_id,
        order_id,
        review_score,
        review_creation_date,
        review_answer_timestamp,
 
        ----------------------------------------------------------------
        -- Tratamento do texto NÃO ESTRUTURADO, tudo em SQL programável:
        -- LIMPEZA do texto cru (title e message)
        ----------------------------------------------------------------

        -- 1. normaliza vazios: string em branco -> NULL
        nullif(trim(regexp_replace(review_comment_title,   '[\n\r]+', ' ')), '') AS titulo,

        -- 2. remove quebras de linha internas que bagunçam o texto livre
        nullif(trim(regexp_replace(review_comment_message, '[\n\r]+', ' ')), '') AS mensagem,

        -- 3. deriva features simples do texto (comprimento, tem comentário?)
        length(trim(review_comment_message)) as tamanho_comentario 

    FROM source 
)
 
SELECT
    review_id,
    order_id,
    review_score,
    review_creation_date,
    review_answer_timestamp,
 
    -- seu rótulo original, baseado na NOTA (mantido)
    CASE
        WHEN review_score >= 4 THEN 'positivo'
        WHEN review_score <= 2 THEN 'negativo'
        ELSE 'neutro'
    END AS sentiment_label,
 
    titulo,
    mensagem,
 
    ----------------------------------------------------------------
    -- 2. TEXTO UNIFICADO: title + message se complementam.
    --    Ex.: título "Não chegou meu produto" + mensagem "Péssimo" (linha 21).
    --    Concatenamos para não perder informação em nenhum dos dois campos.
    ----------------------------------------------------------------
    trim(concat_ws('. ', titulo, mensagem)) AS texto_completo,
 
    ----------------------------------------------------------------
    -- 3. FLAGS de presença (muitas linhas têm um campo, outro, ou nenhum)
    ----------------------------------------------------------------
    (titulo   is not null)                     AS tem_titulo,
    (mensagem is not null)                      AS tem_mensagem,
    (titulo is not null or mensagem is not null) AS tem_comentario
 
FROM limpo
  );

