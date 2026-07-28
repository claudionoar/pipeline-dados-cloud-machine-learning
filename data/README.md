# data/

Cache local dos dados usados pelo pipeline. Nada aqui é versionado (ver `.gitignore`) — os
arquivos são baixados/gerados por script para manter o repositório leve e reprodutível.

```
data/
├── raw/          # CSVs originais baixados do Kaggle (camada equivalente ao "bronze")
└── processed/    # CSVs normalizados pelo s3/processing.py antes do upload (camada "silver")
```

## Como obter os dados originais

1. Crie um token de API em https://www.kaggle.com/settings → API → "Create New Token" e
   preencha `KAGGLE_USERNAME` / `KAGGLE_KEY` no `.env` (raiz do projeto).
2. Baixe os dois datasets:

   ```bash
   pip install kaggle
   export KAGGLE_USERNAME=... KAGGLE_KEY=...

   kaggle datasets download -d karkavelrajaj/amazon-sales-dataset -p data/raw --unzip
   kaggle datasets download -d yasserh/amazon-product-reviews-dataset -p data/raw --unzip
   ```

3. Confirme que os arquivos existem:
   - `data/raw/amazon.csv` (ou nome equivalente) — dataset estruturado de produtos/vendas.
   - `data/raw/*.csv` — dataset de reviews (texto não estruturado).

   Os nomes exatos dos arquivos podem variar conforme a versão publicada no Kaggle;
   `s3/processing.py` tenta detectar automaticamente o CSV correto em `data/raw/` e
   reconhece as variações de nome de coluna mais comuns dos dois datasets (ver
   `docs/dicionario_dados.md`).

## Testar o pipeline sem baixar os dados reais

Todos os scripts em `s3/`, `machine-learning/` e o DAG do Airflow aceitam a flag
`--sample-fallback` (ou a variável de ambiente `PIPELINE_USE_SAMPLE_DATA=true`), que gera uma
pequena amostra sintética de produtos/reviews em memória. Isso permite validar que o código
roda de ponta a ponta antes de esperar o download real ou configurar as credenciais de nuvem.
