# Projeto Final Integrado: Pipeline de Dados em Nuvem para Aprendizagem de Máquina

## Objetivos:

* Pipeline completo, da coleta e organização dos dados à geração de análises, predições e visualizações para o usuário final.  
* Utilizar dados estruturados e pelo menos uma fonte de dados não estruturados ou semiestruturados, como imagens, áudios, vídeos, documentos, logs, arquivos JSON ou dados de sensores.  
* Armazenar os dados brutos em ambiente de nuvem, processá-los e transformá-los em atributos tabulares, carregá-los em uma base analítica, aplicar técnicas de Aprendizagem de Máquina e disponibilizar os resultados em um dashboard voltado à tomada de decisão  
* Tecnologias da **AWS, Snowflake, dbt e Airflow**, bem como de bibliotecas Python para processamento de dados e aprendizagem de máquina.

## Checklist:

* AWS (S3)  
* Snowflake  
* DBT  
* Airflow  
* Pipeline simples com Airflow \-  S3 \- DBT \- Snowflake  
* Datasets estruturado e não-estruturado  
* Modelagem de Dados   
* Algoritmo de Machine Learning Modelagem de Dados 

# Dataset que escolhemos

https://www.kaggle.com/datasets/karkavelrajaj/amazon-sales-dataset


Amazon Product Reviews — texto de avaliações (não estruturado) + ratings, categorias, preços (estruturados). Predição: sentimento, recomendação, churn.

Para o seu stack (AWS + Snowflake + dbt + Airflow), recomendo o Yelp ou o Amazon Reviews: a parte não estruturada (texto/imagens) entra no S3, você processa com Python (NLP/embeddings) gerando atributos tabulares, carrega no Snowflake, modela com dbt e orquestra com Airflow — encaixa naturalmente na arquitetura medalhão (bronze/silver/gold).

https://www.kaggle.com/datasets/yasserh/amazon-product-reviews-dataset

# requisitos:

Não instalar nada no computador.

Queremos usar docker e docker-compose.



# **INSTITUTO FEDERAL DE EDUCAÇÃO, CIÊNCIA E TECNOLOGIA \- GOIÁS**

# **PÓS-GRADUAÇÃO EM INTELIGÊNCIA ARTIFICIAL APLICADA**

# **MÓDULO 2**

# Projeto Final Integrado: Pipeline de Dados em Nuvem para Aprendizagem de Máquina

Aprendizagem de Máquina: Prof. Dr. Sirlon Diniz  
Cloud Computing: Prof. Dr. Raphael Gomes  
Modelagem de Dados para IA: Prof. Dr. Otávio Calaça

## **1\) Visão geral**

Neste projeto final integrado, cada grupo desenvolverá, de forma interdisciplinar, uma solução de IA aplicada ao apoio à decisão, combinando os conhecimentos trabalhados nas disciplinas de **Modelagem de Dados para IA, Aprendizagem de Máquina e Cloud Computing.**

O projeto deverá contemplar a construção de um pipeline completo, da coleta e organização dos dados à geração de análises, predições e visualizações para o usuário final. Para isso, os grupos deverão utilizar dados estruturados e pelo menos uma fonte de dados não estruturados ou semiestruturados, como imagens, áudios, vídeos, documentos, logs, arquivos JSON ou dados de sensores.

A solução deverá armazenar os dados brutos em ambiente de nuvem, processá-los e transformá-los em atributos tabulares, carregá-los em uma base analítica, aplicar técnicas de Aprendizagem de Máquina e disponibilizar os resultados em um dashboard voltado à tomada de decisão.

A arquitetura esperada deverá envolver, preferencialmente, o uso de tecnologias da **AWS, Snowflake, dbt e Airflow**, bem como de bibliotecas Python para processamento de dados e aprendizagem de máquina.

## **2\) OBJETIVOS DE APRENDIZAGEM**

Ao final do projeto, espera-se que os estudantes sejam capazes de:

### **Modelagem de Dados para IA**

1\. Identificar, coletar, organizar e documentar fontes de dados estruturados, semiestruturados e não estruturados adequados ao problema escolhido.   
2\. Construir um pipeline de dados reprodutível, contemplando etapas de ingestão, tratamento, extração de atributos, carga e disponibilização dos dados para análise.  
3\. Modelar dados analíticos em uma base voltada à tomada de decisão, utilizando Snowflake, dbt e boas práticas de organização, transformação, testes e documentação de dados.

### **Aprendizagem de Máquina**

4\. Definir uma tarefa de Aprendizagem de Máquina adequada ao problema escolhido, como classificação, regressão, agrupamento, associação ou detecção de anomalias.  
5\. Preparar os dados para treinamento e avaliação, incluindo seleção de atributos, tratamento de variáveis, divisão entre treino e teste e definição de um baseline.  
6\. Treinar, avaliar e comparar modelos de Aprendizagem de Máquina utilizando métricas compatíveis com a tarefa proposta, registrando os resultados obtidos e discutindo suas limitações. Essa atividade deve ser desenvolvida em duas etapas:  
a. Implementar a técnica de machine learning na forma hard-code e aplicar ao dataset.  
b. Repetir o processo com o mesmo dataset utilizando bibliotecas Python e comparar os resultados.

### **Cloud Computing**

7\. Utilizar serviços de nuvem, especialmente da AWS, para desenvolver, armazenar, processar e disponibilizar componentes da solução, considerando a organização, a segurança básica e a reprodutibilidade.  
8\. Integrar recursos de nuvem ao pipeline do projeto, como armazenamento no S3, processamento em máquinas virtuais, contêineres, funções serverless ou serviços gerenciados.  
9\. Analisar aspectos práticos da implantação da solução em nuvem, incluindo a arquitetura, o monitoramento básico, os custos aproximados, as limitações operacionais e as possibilidades de evolução.

## **3\) ORGANIZAÇÃO E REGRAS**

* **Grupos:** 4 alunos.  
* **Entrega**: repositório \+ apresentação \+ relatório.  
* **Tecnologias**: AWS, Snowflake, dbt, Airflow e Python.  
* **Dados**: cada grupo deve utilizar dados estruturados e pelo menos uma fonte de dados não estruturados ou semiestruturados.  
* **Reprodutibilidade**: o repositório deve permitir reproduzir:  
  * ingestão dos dados;  
  * processamento/extração de atributos;  
  * carga no Snowflake;  
  * execução do dbt;  
  * treinamento ou aplicação do modelo;  
  * geração das predições/resultados.  
* **Nuvem**: a solução deve utilizar pelo menos um serviço da AWS. Deve ser gerado o template Yaml do CloudFormation com a infraestrutura implementada;  
* **Visualização**: os resultados devem ser apresentados em um dashboard em ferramenta de visualização da informação à escolha do grupo.  
* **Apresentação final**: todos os integrantes devem participar e demonstrar compreensão da solução desenvolvida.

## **4\) ESCOPO MÍNIMO OBRIGATÓRIO**

### **4.1 Definição do problema**

Cada grupo deve escolher um problema aplicado de IA voltado ao apoio à decisão.  
O problema deve conter:

* domínio de aplicação;  
* usuário ou tomador de decisão;  
* decisão que será apoiada;  
* fontes de dados utilizadas;  
* tarefa de Aprendizagem de Máquina;  
* resultado esperado da solução.

### **4.2 Conjuntos de Dados**

Cada grupo deve selecionar, construir ou adaptar conjuntos de dados adequados ao problema escolhido.  
Os dados devem permitir a construção de um pipeline completo, contemplando ingestão, armazenamento, transformação, análise, modelagem e visualização.

#### **4.2.1 Requisitos mínimos**

O projeto deve utilizar:

* pelo menos uma fonte de dados estruturados;  
* pelo menos uma fonte de dados não estruturados ou semiestruturados;  
* dados suficientes para treinamento, teste ou análise do modelo;  
* documentação mínima da origem, formato, campos e limitações dos dados.

## **4.3 Processamento e Extração de Atributos**

O grupo deve implementar uma etapa de processamento dos dados.

Para dados estruturados, devem ser realizadas etapas como limpeza, padronização, tratamento de valores ausentes e preparação para carga analítica.

Para dados não estruturados ou semiestruturados, devem ser extraídos atributos que possam ser utilizados em análise ou Aprendizagem de Máquina.

Exemplos:

* imagem → classe, objetos, cores, dimensões ou características visuais;  
* áudio → transcrição, duração, palavras-chave ou características sonoras;  
* vídeo → frames, objetos, eventos ou contagens;  
* documento/texto → palavras-chave, categorias, entidades ou métricas textuais;  
* sensores/logs → agregações, estatísticas, eventos ou anomalias.

## **4.4 Pipeline de ELT (Airflow \+ dbt \+ Snowflake)**

O projeto deve conter um pipeline de ELT utilizando Airflow, dbt e Snowflake.

Requisitos mínimos:

* DAG funcional no Airflow;  
* carga dos dados tratados no Snowflake;  
* modelos dbt para staging, dimensions e facts;  
* pelo menos dois testes dbt;  
* documentação básica dos modelos;  
* tabela final para consumo pelo modelo de Aprendizagem de Máquina e fatos para serem usados por um dashboard.

O pipeline deve permitir reproduzir as principais etapas de preparação e transformação dos dados.

## **4.5 Armazenamento e processamento em nuvem**

O projeto deve utilizar pelo menos um serviço da AWS.

Requisitos mínimos:

* armazenamento de dados brutos e/ou processados em nuvem;  
* organização dos dados em diretórios, camadas ou buckets;  
* documentação da estrutura utilizada;  
* diagrama arquitetural apresentando a proposta de uma solução equivalente 100% em serviços da AWS. Sugestão de ferramenta para gerar o diagrama: [https://online.visual-paradigm.com/](https://online.visual-paradigm.com/)  
* registro de eventuais custos envolvidos.

Exemplos de uso:

* S3 para armazenamento de arquivos;  
* EC2 para execução de scripts, Airflow ou aplicações;  
* Lambda para processamento serverless;  
* ECS ou contêineres para execução de serviços;  
* SageMaker para desenvolvimento do modelo;  
* CloudWatch para logs ou para monitoramento básico.

### **4.6 Aprendizagem de Máquina**

Cada grupo deve implementar pelo menos uma tarefa de Aprendizagem de Máquina.

Tarefas possíveis:

* classificação;  
* regressão;  
* clusterização;  
* associação;  
* detecção de anomalias/outliers.

 Requisitos mínimos:

* definição da tarefa;  
* preparação dos dados;  
* criação de um baseline;  
*  treinamento ou aplicação de pelo menos um modelo utilizando hard-code;  
*  treinamento ou aplicação do mesmo modelo utilizando bibliotecas Python;  
* comparar os resultados entre p  
*  avaliação com métricas adequadas;  
* registro dos resultados ou predições.

### **4.7 Visualização da Informação**

Os resultados devem ser apresentados em um dashboard no Metabase.

Requisitos mínimos:

* indicadores principais do problema;  
* visualização dos dados tratados;  
* visualização dos resultados do modelo;  
* pelo menos um filtro ou recorte analítico;   
* explicação de como o dashboard apoia a tomada de decisão.

## **5\) AVALIAÇÃO OBRIGATÓRIA**

### **5.1 Conjunto de avaliação**

Cada grupo deverá construir um conjunto de avaliação adequado ao seu problema.

Esse conjunto pode conter:

* dados separados para teste;  
* registros rotulados manualmente;  
* amostra validada pelo grupo;  
* conjunto de casos esperados;  
* perguntas de negócio que o dashboard deve responder.

O conjunto de avaliação deve permitir verificar se a solução funciona objetivamente.

### **5.2 Métricas**

As métricas devem ser escolhidas conforme o tipo de tarefa.

Para classificação:

* accuracy;  
* precision;  
* recall;  
* F1-score;  
* matriz de confusão.

Para regressão:

* MAE;  
* RMSE;  
* R2;  
* comparação com média histórica ou baseline simples.

Para clusterização:

* silhouette score;  
* análise dos perfis dos clusters;  
* interpretação qualitativa dos clusters.

Para associação:

* suporte;  
* confiança;  
* lift;  
* interpretação das regras.

### **5.3 Avaliação do pipeline**

Além do modelo de Aprendizagem de Máquina, o grupo deverá avaliar aspectos do pipeline:

* execução correta das etapas;  
* organização dos dados;  
* qualidade dos dados após transformação;  
* testes dbt;  
* rastreabilidade entre dado bruto, dado tratado e predição;  
* limitações da arquitetura.

### **5.4 Avaliação qualitativa**

O grupo deverá apresentar uma análise qualitativa contendo:

* exemplos de acertos;  
* exemplos de erros;  
* possíveis causas dos erros;  
* limitações dos dados;  
* riscos de uso da solução;  
* melhorias futuras.

## **6\) Entregáveis**

### **6.1 Repositório (obrigatório)**

O repositório deve conter o código, configurações e instruções necessárias para reproduzir as principais etapas do projeto.

Deve incluir:

* README com descrição do projeto e instruções de execução;  
* scripts, notebooks e/ou DAGs utilizados no pipeline;  
* projeto dbt, quando aplicável;  
* código de processamento, extração de atributos e Aprendizagem de Máquina;  
* instruções para obtenção ou geração dos dados;  
* template Yaml do CloudFormation;  
* evidências de execução, como prints, logs ou exemplos de saída.

### **6.2 Apresentação (obrigatório)**

A apresentação deve demonstrar a solução objetivamente, destacando o problema, a arquitetura, o pipeline, o modelo de Aprendizagem de Máquina e os resultados obtidos.  
Durante a apresentação, o grupo deve mostrar:

* visão geral da solução;  
* dados utilizados e atributos extraídos;  
* execução ou evidências do pipeline;  
* tabelas/modelos no Snowflake/dbt;  
* resultados do modelo de Aprendizagem de Máquina;  
* dashboard para visualização de informação;  
* principais decisões que a solução permite apoiar.

Todos os integrantes devem participar da apresentação e demonstrar compreensão da solução desenvolvida.

### **6.3 Relatório (obrigatório)**

O relatório deve documentar a solução desenvolvida pelo grupo.  
Deve conter:

* definição do problema e decisão apoiada;  
* descrição dos conjuntos de dados utilizados;  
* arquitetura geral da solução (como foi desenvolvida e a arquitetura equivalente totalmente em nuvem);;  
*  processamento e extração de atributos;  
* pipeline de ELT com Airflow, dbt e Snowflake;  
* uso de recursos da AWS;  
* tarefa de Aprendizagem de Máquina, modelos e métricas;  
* dashboard e principais análises;  
* limitações e próximos passos.