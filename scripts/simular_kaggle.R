#!/usr/bin/env Rscript
# Simulacao de Monte Carlo de AAS e AAS estratificada sobre o dataset do
# Kaggle (populacao conhecida). Plano §2.1 e §4.5.
#
# Exemplo:
#   Rscript scripts/simular_kaggle.R --estratificar-por buyin --n 60 --n-rep 5000 --seed 42
#
# Defaults vem de variaveis de ambiente (ver `.env.example`).

suppressPackageStartupMessages(library(optparse))

for (arquivo in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(arquivo)
}

option_list <- list(
  make_option(
    "--data-path",
    default = Sys.getenv("KAGGLE_PATH", "data/raw/kaggle/poker_tournament_survival.csv")
  ),
  make_option(
    "--estratificar-por",
    default = Sys.getenv("KAGGLE_ESTRATIFICAR_POR", "buyin"),
    help = "buyin (faixas do campo), skill (quartis, didatico) ou nenhum."
  ),
  make_option("--n", default = as.integer(Sys.getenv("TAMANHO_AMOSTRA", 60))),
  make_option("--n-rep", default = as.integer(Sys.getenv("N_REPLICAS", 5000))),
  make_option("--seed", default = as.integer(Sys.getenv("RANDOM_SEED", 42)))
)
args <- parse_args(
  OptionParser(
    description = "Monte Carlo de AAS/AAS estratificada no dataset do Kaggle",
    option_list = option_list
  ),
  convert_hyphens_to_underscores = TRUE
)

populacao <- carregar_populacao_kaggle(args$data_path, args$estratificar_por)
cat(sprintf(
  "Populacao: %d jogadores | estratificacao: %s | n = %d | replicas = %d | seed = %d\n",
  nrow(populacao), args$estratificar_por, args$n, args$n_rep, args$seed
))
if ("estrato" %in% names(populacao)) print(table(populacao$estrato))

dir.create("data/processed", showWarnings = FALSE)
for (variavel in c("roi", "lucrativo")) {
  parametro <- mean(populacao[[variavel]])
  sims <- simular_planos(populacao, variavel, args$n, args$n_rep, args$seed)
  resumo <- resumir_simulacao(sims, parametro)
  cat(sprintf("\n== %s (parametro verdadeiro = %.4f) ==\n", variavel, parametro))
  print(resumo, digits = 4)
  write.csv(
    resumo,
    sprintf("data/processed/simulacao_kaggle_%s_%s.csv", args$estratificar_por, variavel),
    row.names = FALSE
  )
}
