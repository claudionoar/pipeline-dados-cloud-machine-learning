# Dicionário de dados

## Fontes brutas (camada bronze)

### 1. `amazon-sales-dataset` (estruturado)

- **Origem**: https://www.kaggle.com/datasets/karkavelrajaj/amazon-sales-dataset
- **Formato**: CSV, ~1.500 produtos do marketplace indiano da Amazon.
- **Colunas originais esperadas** (podem variar levemente entre versões republicadas do
  dataset — `s3/processing.py` reconhece os aliases mais comuns, ver `SALES_ALIASES`):

  | Coluna original | Descrição |
  |---|---|
  | `product_id` | ASIN do produto |
  | `product_name` | Nome/título do produto |
  | `category` | Categoria hierárquica separada por `\|` (ex.: `Electronics\|Accessories\|...`) |
  | `discounted_price` | Preço com desconto (string com símbolo de moeda, ex.: `₹399`) |
  | `actual_price` | Preço de tabela |
  | `discount_percentage` | Percentual de desconto (string, ex.: `64%`) |
  | `rating` | Rating médio do produto (1 a 5, pode conter valores inválidos/texto) |
  | `rating_count` | Quantidade de avaliações (string com separador de milhar) |
  | `about_product` | Descrição/bullet points do produto |
  | `user_id`, `user_name`, `review_id`, `review_title`, `review_content` | Amostra de reviews embutida no próprio dataset (não usada diretamente — o corpus de reviews vem do dataset 2, mais volumoso) |
  | `img_link`, `product_link` | URLs |

- **Limitações**: cobre apenas o marketplace indiano (preços em rúpias); `rating`/
  `rating_count` são agregados no momento da coleta, não uma série temporal.

### 2. `amazon-product-reviews-dataset` (não estruturado)

- **Origem**: https://www.kaggle.com/datasets/yasserh/amazon-product-reviews-dataset
- **Formato**: CSV, dezenas de milhares de reviews de texto livre.
- **Colunas originais esperadas** (schema no estilo "Amazon Fine Food Reviews"; aliases
  reconhecidos em `s3/processing.py::REVIEWS_ALIASES`):

  | Coluna original | Descrição |
  |---|---|
  | `Id` / `review_id` | Identificador da review |
  | `ProductId` / `asin` | Produto avaliado |
  | `UserId` / `reviewerID` | Autor da review |
  | `Summary` / `summary` | Título curto da review |
  | `Text` / `reviewText` | Corpo do texto da review (**fonte não estruturada principal**) |
  | `Score` / `overall` | Rating dado pelo usuário (1 a 5) — usado para derivar o rótulo de sentimento |
  | `Time` / `reviewTime` | Data da review (unix timestamp ou string) |

- **Limitações importantes**:
  - Os produtos deste dataset **não correspondem** ao catálogo do dataset 1 (mercados/
    períodos diferentes) — o `product_id` de boa parte das reviews não terá correspondência
    em `dim_product`. Isso é esperado: o corpus de reviews é usado para treinar/avaliar o
    classificador de sentimento de forma independente do catálogo específico; o join com
    produto (quando existe) só enriquece a análise por categoria/preço.
  - O rótulo de sentimento é **derivado do rating**, não anotado manualmente — reviews
    "3 estrelas" costumam ser ambíguas entre neutro/levemente negativo.

## Esquema canônico (camada silver, saída de `s3/processing.py`)

### `sales.csv` → `RAW.SALES`

| Coluna | Tipo | Observação |
|---|---|---|
| `product_id` | string | chave primária |
| `product_name` | string | |
| `category`, `category_root` | string | `category_root` = primeiro segmento de `category` |
| `discounted_price`, `actual_price`, `discount_percentage` | float | limpos de símbolos de moeda/`%` |
| `rating` | float | 1–5 |
| `rating_count` | int | |
| `about_product`, `img_link`, `product_link` | string | |
| `ingested_at` | timestamp | data/hora do processamento |

### `reviews.csv` → `RAW.REVIEWS`

| Coluna | Tipo | Observação |
|---|---|---|
| `review_id` | string | chave primária (gerado se ausente na fonte) |
| `product_id` | string | pode não existir em `dim_product` (ver limitações acima) |
| `user_id`, `review_title`, `review_text` | string | |
| `rating` | int | 1–5 |
| `review_date` | timestamp | pode ser nulo |
| `word_count`, `char_count`, `exclamation_count` | int | atributos extraídos do texto |
| `sentiment_label` | string | `positive` / `neutral` / `negative`, derivado do `rating` |
| `ingested_at` | timestamp | |

### `predictions.csv` (saída de `machine-learning/`) → `RAW.ML_PREDICTIONS`

| Coluna | Tipo | Observação |
|---|---|---|
| `review_id`, `product_id` | string | referência à review avaliada (conjunto de teste) |
| `true_label` | string | rótulo real |
| `predicted_label_hardcode` | string | predição do Naive Bayes implementado do zero |
| `predicted_label_sklearn` | string | predição do Naive Bayes via scikit-learn |
| `model_version`, `predicted_at` | string/timestamp | rastreabilidade |
