#!/usr/bin/env Rscript
# Sorteio da amostra de campo (SharkScope).
#
# Etapa 1 -- torneios (1o estagio), a partir da moldura do periodo:
#   Rscript scripts/sortear_amostra.R torneios --n-por-estrato 5 --seed 42
#
# Etapa 2 -- jogadores (2o estagio), a partir dos inscritos dos sorteados:
#   Rscript scripts/sortear_amostra.R jogadores --m-por-torneio 4 --n-reserva 4 --seed 42

suppressPackageStartupMessages(library(optparse))

for (arquivo in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(arquivo)
}

option_list <- list(
  make_option("--moldura", default = "data/raw/sharkscope/moldura_torneios.csv"),
  make_option("--inscritos", default = "data/raw/sharkscope/inscritos.csv"),
  make_option("--n-por-estrato", default = as.integer(Sys.getenv("N_POR_ESTRATO", 5))),
  make_option("--m-por-torneio", default = as.integer(Sys.getenv("M_POR_TORNEIO", 4))),
  make_option("--n-reserva", default = as.integer(Sys.getenv("N_RESERVA", 4))),
  make_option("--seed", default = as.integer(Sys.getenv("RANDOM_SEED", 42)))
)
parser <- OptionParser(
  usage = "%prog [torneios|jogadores] [opcoes]",
  option_list = option_list
)
entrada <- parse_args(
  parser,
  positional_arguments = 1, convert_hyphens_to_underscores = TRUE
)
etapa <- entrada$args
args <- entrada$options

if (etapa == "torneios") {
  sorteados <- sortear_torneios(carregar_moldura(args$moldura), args$n_por_estrato, args$seed)
  saida <- "data/raw/sharkscope/torneios_sorteados.csv"
  write.csv(sorteados, saida, row.names = FALSE)
  cat(sprintf("%d torneios sorteados (seed = %d) -> %s\n", nrow(sorteados), args$seed, saida))
} else if (etapa == "jogadores") {
  sorteados <- sortear_jogadores(
    carregar_inscritos(args$inscritos), args$m_por_torneio, args$n_reserva, args$seed
  )
  saida <- "data/raw/sharkscope/jogadores_sorteados.csv"
  write.csv(sorteados, saida, row.names = FALSE)
  cat(sprintf("%d jogadores sorteados (seed = %d) -> %s\n", nrow(sorteados), args$seed, saida))
} else {
  stop("Etapa invalida: use 'torneios' ou 'jogadores'.")
}
