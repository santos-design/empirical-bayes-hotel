#Criar pastas necessárias (se não existirem)
dir.create("data", showWarnings = FALSE)
dir.create("scripts", showWarnings = FALSE)
dir.create("outputs", showWarnings = FALSE)
dir.create("figs", showWarnings = FALSE)

#!/usr/bin/env Rscript
# =============================================================================
# Empirical Bayes Shrinkage para Taxas de Cancelamento Hoteleiro
# =============================================================================
# Autor: Ivan Manoel dos Santos da Rosa
# Data: 2026
# Descrição:
#   Implementa estimativa Bayesiana empírica para melhorar estimativas de taxas
#   de cancelamento em segmentos hotel-país com poucas observações. A técnica
#   contrai estimativas extremas em direção a um prior global, resolvendo o
#   problema de "pequenas amostras" comum em métricas de negócio.
#
# Valor de Negócio:
#   - Identificar segmentos hotel-país verdadeiramente problemáticos
#   - Evitar agir com base em ruído de segmentos com poucas reservas
#   - Rankings mais confiáveis para alocação de recursos
# =============================================================================

# -----------------------------------------------------------------------------
# 1. Configuração Inicial
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  install.packages("tidyverse")   # Manipulação e visualização de dados
  install.packages("MASS")        # fitdistr para estimação de parâmetros Beta
  install.packages("VGAM")        # Distribuição Beta-Binomial (validação)
  install.packages("gridExtra")   # Gráficos em múltiplos painéis 
  install.packages("knitr")       # Formatação de tabelas
  install.packages("bbmle")       # Maximum likelihood estimation (validação Beta-Binomial)
 
  
  library(tidyverse)
  library(MASS)
  library(VGAM)
  library(gridExtra)
  library(knitr)
  library(bbmle)
  
})

set.seed(42) # Reprodutibilidade

# -----------------------------------------------------------------------------
# 2. Carregamento e Exploração Inicial dos Dados
# -----------------------------------------------------------------------------
#' Carrega dataset de reservas hoteleiras do Kaggle
#' Fonte: https://www.kaggle.com/datasets/jessemostipak/hotel-booking-demand 

carregar_dados_hotel <- function(caminho_arquivo = "data/hotel_bookings.csv") {
  if (!file.exists(caminho_arquivo)) {
    stop("Dataset não encontrado. Faça o download do Kaggle.")
  }
  
  df <- read.csv(caminho_arquivo, stringsAsFactors = FALSE)
  
  cat(sprintf("Dados carregados: %d linhas, %d colunas\n", nrow(df), ncol(df)))
  cat(sprintf("Período: %s a %s\n", 
              min(df$arrival_date_year), max(df$arrival_date_year)))
  
  return(df)
}

dados_raw <- carregar_dados_hotel()

# -----------------------------------------------------------------------------
# 3. Preparação: Agregação por Segmentos Hotel-País
# -----------------------------------------------------------------------------
#' Cria estrutura sucessos/total para empirical Bayes
#' - sucesso: reservas canceladas (is_canceled = 1)
#' - total: total de reservas
#' - segmento: combinação hotel-país

segmentos_hotel <- dados_raw %>%
  filter(country != "") %>% # Remove origins desconhecidas
  group_by(hotel, country) %>%
  summarise(
    total_reservas = n(),
    cancelamentos = sum(is_canceled),
    .groups = "drop"
  ) %>%
  mutate(
    taxa_bruta = cancelamentos / total_reservas,
    log_reservas = log10(total_reservas) # Para visualização 
  ) %>%
  filter(total_reservas > 0) # Segurança 

cat(sprintf("\nDataset de Análise: %d segmentos hotel-país\n",
            nrow(segmentos_hotel)))
cat(sprintf("Média de reservas por Segmento: %.1f\n",
            mean(segmentos_hotel$total_reservas)))
cat(sprintf("Taxa Bruta: [%.3f, %.3f]\n", 
            min(segmentos_hotel$taxa_bruta), max(segmentos_hotel$taxa_bruta)))

# -----------------------------------------------------------------------------
# 4. Estimação da Distribuição Prior (Beta)
# -----------------------------------------------------------------------------
#' Ajusta distribuição Beta aos segmentos estáveis (>= 100 reservas)
#' Isso nos dá nossa crença a priori sobre taxas de cancelamento antes de
#' vermos os dados de cada segmento individual.

segmentos_estaveis <- segmentos_hotel %>%
  filter(total_reservas >= 100)

ajuste_beta<- fitdistr(segmentos_estaveis$taxa_bruta,
                       dbeta,
                       start = list(shape1 = 1, shape2 = 10))

alpha0 <- ajuste_beta$estimate[1]
beta0 <- ajuste_beta$estimate[2]
media_prior <- alpha0 / (alpha0 + beta0)
tamanho_efetivo_prior <- alpha0 + beta0

cat("\n===Distribuição Prior ===\n")
cat(sprintf("Parâmetros Beta: å0 = %.2f, ß0 = %.2f\n", alpha0, beta0))
cat(sprintf("Média do prior: %.1f%%\n", media_prior * 100))
cat(sprintf("Tamanho Amostral Efetivo: %.0f reservas/n", tamanho_efetivo_prior))

# -----------------------------------------------------------------------------
# 5. Estimativa Bayesiana Empírica (Shrinkage)
# -----------------------------------------------------------------------------
#' Aplica fórmula de contração: (cancelamentos + α0) / (total + α0 + β0)
#' Isso puxa estimativas extremas em direção à média do prior, com força de
#' contração inversamente proporcional ao total de reservas.

segmentos_hotel <- segmentos_hotel %>%
  mutate(
    estimativa_bayesiana = (cancelamentos + alpha0) / (total_reservas + alpha0 + beta0
  ),
  erro_padrao = sqrt(estimativa_bayesiana * (1 - estimativa_bayesiana) / 
                       (total_reservas + alpha0 + beta0)),
  shrinkage = abs(taxa_bruta - estimativa_bayesiana),
  # Intervalo de credibilidade 95%
  ic_inferior = estimativa_bayesiana - 1.96 * erro_padrao,
  ic_superior = estimativa_bayesiana + 1.96 * erro_padrao
  )

# -----------------------------------------------------------------------------
# 6. Validação: Estimação Beta-Binomial
# -----------------------------------------------------------------------------
#' Usa todos os dados sem filtro via máxima verossimilhança Beta-Binomial
#' Serve como validação da abordagem com filtro

log_verossimilhança_betabinom <- function(alpha, beta) {
  -sum(dbetabinom.ab(segmentos_hotel$cancelamentos, 
                     segmentos_hotel$total_reservas, 
                     alpha, beta, log = TRUE))
}

ajuste_bb <- mle2(log_verossimilhança_betabinom, 
                  start = list(alpha = alpha0, beta = beta0),
                  method = "L-BFGS-B",
                  lower = c(alpha = 0.1, beta = 0.1))

alpha0_bb <- coef(ajuste_bb)[1]
beta0_bb <- coef(ajuste_bb)[2]

cat("\n=== VALIDAÇÃO ===\n")
cat(sprintf("Método com filtro: α0 = %.2f, β0 = %.2f\n", alpha0, beta0))
cat(sprintf("Beta-Binomial:     α0 = %.2f, β0 = %.2f\n", alpha0_bb, beta0_bb))

# -----------------------------------------------------------------------------
# 7. Visualizações
# -----------------------------------------------------------------------------
#' Gráficos publicáveis para demonstrar o efeito do shrinkage

tema_portfolio <- theme_minimal() +
  theme(
    text = element_text(family = "Helvetica"),
    plot.title = element_text(size = 16, face = "bold"),
    plot.subtitle = element_text(size = 12, color = "gray40"),
    axis.title = element_text(size = 11),
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

# Gráfico principal: Taxa Bruta vs Estimativa Bayesiana
p_shrinkage <- ggplot(segmentos_hotel, aes(x = taxa_bruta, y = estimativa_bayesiana)) +
  geom_point(aes(size = total_reservas, color = hotel), alpha = 0.6) +
  geom_abline(slope = 1, intercept = 0, color = "red", 
              linetype = "dashed", size = 0.8) +
  geom_hline(yintercept = media_prior, color = "blue", 
             linetype = "dotted", size = 0.8) +
  scale_size_continuous(range = c(1, 10), trans = "log10",
                        breaks = c(10, 100, 1000, 10000)) +
  scale_color_manual(values = c("City Hotel" = "#2E86AB", 
                                "Resort Hotel" = "#A23B72")) +
  labs(
    title = "Shrinkage Bayesiano Empírico: Taxas de Cancelamento Hoteleiro",
    subtitle = sprintf("Prior: Beta(%.1f, %.1f) | Média Global: %.1f%%", 
                       alpha0, beta0, media_prior * 100),
    x = "Taxa Bruta (Cancelamentos / Reservas)",
    y = "Estimativa Bayesiana (Pós-Shrinkage)",
    size = "Reservas (log10)",
    color = "Tipo de Hotel",
    caption = "Pontos próximos à diagonal: estimativas confiáveis | Pontos próximos à linha azul: fortemente contraídos"
  ) +
  tema_portfolio
  
# Gráfico de distribuição: antes e depois
p_distribuicao <- segmentos_hotel %>%
  ggplot(aes(x = taxa_bruta)) +
  geom_histogram(aes(y = after_stat(density), fill = "Taxas Brutas"), 
                 bins = 40, alpha = 0.5) +
  geom_histogram(aes(x = estimativa_bayesiana, y = after_stat(density), 
                     fill = "Estimativas Bayesianas"), 
                 bins = 40, alpha = 0.5) +
  geom_vline(xintercept = media_prior, color = "blue", linetype = "dotted") +
  scale_fill_manual(values = c("Taxas Brutas" = "gray70", 
                               "Estimativas Bayesianas" = "#2E86AB")) +
  labs(
    title = "Mudança na Distribuição Após Shrinkage",
    x = "Taxa de Cancelamento",
    y = "Densidade",
    fill = ""
  ) +
  tema_portfolio

print(p_shrinkage)
print(p_distribuicao)

# Salvar gráficos
ggsave("figs/grafico_shrinkage.png", p_shrinkage, width = 12, height = 8, dpi = 300)
ggsave("figs/mudanca_distribuicao.png", p_distribuicao, width = 10, height = 6, dpi = 300)

# -----------------------------------------------------------------------------
# 8. Insights de Negócio
# -----------------------------------------------------------------------------

# Top 10 maiores taxas (bruto vs Bayesiano)
top_bruto <- segmentos_hotel %>%
  arrange(desc(taxa_bruta)) %>%
  dplyr::select(hotel, country, total_reservas, taxa_bruta, estimativa_bayesiana) %>%
  head(10) %>%
  mutate(across(where(is.numeric), ~round(., 3)))

top_bayesiano <- segmentos_hotel %>%
  arrange(desc(estimativa_bayesiana)) %>%
  dplyr::select(hotel, country, total_reservas, taxa_bruta, estimativa_bayesiana) %>%
  head(10) %>%
  mutate(across(where(is.numeric), ~round(., 3)))

cat("\n=== TOP 10 POR TAXA BRUTA (NÃO CONFIÁVEL) ===\n")
print(kable(top_bruto, format = "simple"))

cat("\n=== TOP 10 POR ESTIMATIVA BAYESIANA (CONFIÁVEL) ===\n")
print(kable(top_bayesiano, format = "simple"))

# Segmentos com maior shrinkage
segmentos_volateis <- segmentos_hotel %>%
  mutate(mudanca = abs(taxa_bruta - estimativa_bayesiana)) %>%
  arrange(desc(mudanca)) %>%
  dplyr::select(hotel, country, total_reservas, taxa_bruta, estimativa_bayesiana, mudanca) %>%
  head(10)

cat("\n=== Segmentos mais Voláteis (Maior Shrinkage) ===\n")
print(kable(segmentos_volateis, format = "simple"))

# Comparação por Hotel
resumo_hotel <- segmentos_hotel %>%
  group_by(hotel) %>%
  summarise(
    segmentos = n(),
    total_reservas = sum(total_reservas),
    total_cancelamentos = sum(cancelamentos),
    taxa_bruta_ponderada = total_cancelamentos / total_reservas,
    taxa_bayesiana_ponderada = sum(estimativa_bayesiana *
                                     (total_reservas + alpha0 + beta0)) /
                                  sum(total_reservas + alpha0 + beta0)
  )

cat("\n=== Comparação Entre Hotéis ===\n")
print(kable(resumo_hotel, format = "simple", digits = 3))

# -----------------------------------------------------------------------------
# 9. Exportação dos Resultados
# -----------------------------------------------------------------------------
#' Salva dataset enriquecido para análises futuras ou dashboards

write_csv(segmentos_hotel, "outputs/taxas_cancelamento_eb.csv")

cat("\n=== ANÁLISE CONCLUÍDA ===\n")
cat("Resultados exportados para: outputs/taxas_cancelamento_eb.csv\n")
cat("Visualizações salvas em: figs/grafico_shrinkage.png, figs/mudanca_distribuicao.png\n")
         


