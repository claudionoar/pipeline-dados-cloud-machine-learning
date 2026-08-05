-- Camada MARTS / Enriquecimento: features estruturadas do texto dos reviews.
-- Transforma o comentário livre (title + message) em COLUNAS analisáveis.
-- Materializado como VIEW.

{{ config(materialized='view') }}

-- CTE que carrega todos os registros da camada de staging de avaliações
WITH reviews AS (
    SELECT * FROM {{ ref('stg_order_reviews') }}

),

-- CTE que deriva as features estruturadas a partir do texto livre das avaliações
features AS (

    SELECT
        review_id,                -- identificador da avaliação
        order_id,                 -- identificador do pedido avaliado
        review_score,             -- nota atribuída na avaliação
        sentiment_label,          -- rótulo pela NOTA (vindo do staging)
        titulo,                   -- título do comentário
        mensagem,                 -- corpo do comentário
        texto_completo,           -- título + mensagem concatenados
        tem_comentario,           -- flag indicando presença de texto

        ----------------------------------------------------------------
        -- 1. VOLUME do texto
        ----------------------------------------------------------------
        COALESCE(LENGTH(texto_completo), 0)                  AS num_caracteres,  -- total de caracteres do texto
        CASE
            WHEN texto_completo IS NULL THEN 0
            ELSE REGEXP_COUNT(texto_completo, '\\s+') + 1
        END                                                  AS num_palavras,    -- total de palavras (contando espaços)

        ----------------------------------------------------------------
        -- 2. ESTILO (sinais visíveis na planilha)
        --    - caixa alta: linha 18 "GOSTARIA DE SABER O QUE HOUVE..."
        --    - exclamação: linha 31 "Não gostei ! Comprei gato por lebre"
        ----------------------------------------------------------------
        (texto_completo IS NOT NULL
         AND texto_completo = UPPER(texto_completo))          AS texto_em_caixa_alta,  -- TRUE se o texto está todo em maiúsculas
        (COALESCE(REGEXP_COUNT(texto_completo, '!'), 0) > 0)  AS tem_exclamacao,        -- TRUE se há ao menos uma exclamação

        ----------------------------------------------------------------
        -- 3. SENTIMENTO PELO TEXTO (heurística por palavras-chave).
        --    Diferente do sentiment_label, que olha só a nota.
        ----------------------------------------------------------------
        CASE
            WHEN texto_completo IS NULL THEN 'sem_comentario'
            WHEN LOWER(texto_completo) LIKE '%recomendo%'
              OR LOWER(texto_completo) LIKE '%ótimo%'
              OR LOWER(texto_completo) LIKE '%adorei%'
              OR LOWER(texto_completo) LIKE '%excelente%'
              OR LOWER(texto_completo) LIKE '%nota 10%'
              OR LOWER(texto_completo) LIKE '%antes do prazo%' THEN 'positivo'
            WHEN LOWER(texto_completo) LIKE '%não chegou%'
              OR LOWER(texto_completo) LIKE '%não recebi%'
              OR LOWER(texto_completo) LIKE '%péssimo%'
              OR LOWER(texto_completo) LIKE '%não gostei%'
              OR LOWER(texto_completo) LIKE '%gato por lebre%'
              OR LOWER(texto_completo) LIKE '%não recomendo%'  THEN 'negativo'
            ELSE 'neutro'
        END                                                   AS sentimento_texto  -- sentimento inferido pelo texto (não pela nota)

    FROM reviews

)

-- Seleção final: mantém todas as features e adiciona a análise de coerência nota vs. texto
SELECT
    *,

    ----------------------------------------------------------------
    -- 4. COERÊNCIA: nota (sentiment_label) vs. texto (sentimento_texto).
    --    Acha divergências como nota 5 com texto de reclamação.
    ----------------------------------------------------------------
    CASE
        WHEN sentimento_texto = 'sem_comentario'      THEN 'sem_texto'
        WHEN sentiment_label = 'positivo' AND sentimento_texto = 'negativo' THEN 'divergente'
        WHEN sentiment_label = 'negativo' AND sentimento_texto = 'positivo' THEN 'divergente'
        ELSE 'coerente'
    END AS coerencia_nota_texto  -- classifica se nota e texto estão alinhados ou divergentes

FROM features
