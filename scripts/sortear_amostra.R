#!/usr/bin/env Rscript
# Sorteio da amostra de campo (SharkScope).
#
# Fase 0 -- blocos de tempo (estagio temporal, Metodologia §6):
#   Rscript scripts/sortear_amostra.R blocos --n-blocos 6 --seed 164363
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
  make_option("--inicio", default = "2026-10-11", help = "Primeiro dia do periodo [%default]"),
  make_option("--dias", default = 10L, help = "Dias corridos do periodo [%default]"),
  make_option("--horas-bloco", default = 2L, help = "Duracao de cada bloco, em horas [%default]"),
  make_option("--fuso", default = "America/Sao_Paulo", help = "Fuso dos horarios [%default]"),
  make_option("--n-blocos", default = 6L, help = "Blocos sorteados, b [%default]"),
  make_option("--log", default = "data/raw/sharkscope/log_coleta.csv"),
  make_option("--moldura", default = "data/raw/sharkscope/moldura_torneios.csv"),
  make_option("--inscritos", default = "data/raw/sharkscope/inscritos.csv"),
  make_option("--n-por-estrato", default = as.integer(Sys.getenv("N_POR_ESTRATO", 5))),
  make_option("--m-por-torneio", default = as.integer(Sys.getenv("M_POR_TORNEIO", 4))),
  make_option("--n-reserva", default = as.integer(Sys.getenv("N_RESERVA", 4))),
  make_option("--seed", default = as.integer(Sys.getenv("RANDOM_SEED", 42)))
)
parser <- OptionParser(
  usage = "%prog [blocos|torneios|jogadores] [opcoes]",
  option_list = option_list
)
entrada <- parse_args(
  parser,
  positional_arguments = 1, convert_hyphens_to_underscores = TRUE
)
etapa <- entrada$args
args <- entrada$options

if (etapa == "blocos") {
  blocos <- gerar_blocos(args$inicio, args$dias, args$horas_bloco, args$fuso)
  sorteados <- sortear_blocos(blocos, args$n_blocos, args$seed)
  saida <- "data/raw/sharkscope/blocos_sorteados.csv"
  write.csv(sorteados, saida, row.names = FALSE)
  registrar_log_coleta(
    args$log,
    fase = "0", evento = "sorteio_blocos",
    detalhe = sprintf(
      "AASs de b = %d entre B = %d blocos de %d h a partir de %s (%s); sorteados (bloco_id): %s",
      args$n_blocos, nrow(blocos), args$horas_bloco, args$inicio, args$fuso,
      paste(sorteados$bloco_id[order(sorteados$ordem_sorteio)], collapse = " ")
    ),
    seed = args$seed
  )
  cat(sprintf(
    "%d de %d blocos sorteados (seed = %d) -> %s\n",
    nrow(sorteados), nrow(blocos), args$seed, saida
  ))
  colunas <- c("ordem_sorteio", "bloco_id", "inicio", "fim", "dia_semana")
  print(sorteados[, colunas], row.names = FALSE)
} else if (etapa == "torneios") {
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
  stop("Etapa invalida: use 'blocos', 'torneios' ou 'jogadores'.")
}
