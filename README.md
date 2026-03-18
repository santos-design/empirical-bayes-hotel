# Empirical Bayes Shrinkage para Análise de Cancelamentos Hoteleiros

<p align="center">
  <img src="https://img.shields.io/badge/R-4.0%2B-blue?style=for-the-badge&logo=r&logoColor=white" alt="R version"/>
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License MIT"/>
  <img src="https://img.shields.io/badge/Status-Concluído-green?style=for-the-badge" alt="Status Concluído"/>
</p>

## 📋 Sobre o Projeto

Este repositório implementa **estimação Bayesiana empírica** para resolver um problema comum em análise de dados: como estimar taxas de cancelamento de forma confiável quando se tem segmentos com poucas reservas.

Utilizando dados públicos de reservas hoteleiras do Kaggle, o projeto demonstra como taxas brutas podem ser enganosas e como o método de **shrinkage** (contração) produz estimativas mais realistas.

### O Problema

| Segmento | Reservas | Cancelamentos | Taxa Bruta | Problema |
|----------|----------|---------------|------------|----------|
| City Hotel + País X | 2 | 2 | 100% | Amostra pequena, não confiável |
| City Hotel + Portugal | 48.590 | 20.552 | 42.3% | Estimativa confiável |

### A Solução
estimativa_bayesiana = (cancelamentos + 3.45) / (reservas + 13.14)

text

## 📊 Resultados Principais

### Prior Estimado
- **α₀ = 3.45** (cancelamentos fictícios)
- **β₀ = 9.69** (não-cancelamentos fictícios)
- **Média do prior = 26.3%**
- **Tamanho efetivo = 13.14 reservas**

### Segmentos Mais Voláteis

| Hotel | País | Reservas | Taxa Bruta | Est. Bayesiana | Shrinkage |
|-------|------|----------|------------|----------------|-----------|
| City Hotel | HND | 1 | 100% | 31.5% | 68.5% |
| City Hotel | BEN | 3 | 100% | 40.0% | 60.0% |
| City Hotel | MAC | 15 | 100% | 65.6% | 34.4% |

### Comparação entre Hotéis

| Hotel | Segmentos | Reservas | Taxa Bruta | Taxa Bayesiana |
|-------|-----------|----------|------------|----------------|
| City Hotel | 167 | 79.330 | 41.7% | 51.5% |
| Resort Hotel | 126 | 40.060 | 27.8% | 29.8% |

### Visualizações

![Shrinkage Plot](figs/grafico_shrinkage.png)
*Gráfico: Taxa Bruta vs Estimativa Bayesiana*

![Distribuição](figs/mudanca_distribuicao.png)
*Distribuição antes e depois do shrinkage*

## 🚀 Como Executar

### Pré-requisitos
- R >= 4.0.0
- RStudio
- Git

### Passo a Passo

```bash
# Clone o repositório
git clone https://github.com/santos-design/empirical-bayes-hotel.git
r
# No RStudio, instale as dependências
install.packages(c("tidyverse", "MASS", "VGAM", "gridExtra", "knitr", "bbmle"))

# Execute a análise
source("scripts/analyse_hotel.R")
Dados: Faça o download do dataset Hotel Booking Demand do Kaggle e coloque o arquivo hotel_bookings.csv na pasta data/ do projeto.

📁 Estrutura do Projeto
text
empirical-bayes-hotel/
├── scripts/          # Código fonte
├── data/             # Dados brutos (não versionados)
├── outputs/          # Resultados processados
├── figs/             # Visualizações geradas
└── README.md         # Documentação
👤 Autor
Ivan Santos

LinkedIn: https://www.linkedin.com/in/ivan-santos-8046a8355/

GitHub: https://github.com/santos-design

