#!/usr/bin/env Rscript
# Sorteio da amostra de campo (SharkScope).
#
# Fase 0 -- blocos de tempo (estagio temporal, Metodologia §6):
#   Rscript scripts/sortear_amostra.R blocos --n-blocos 6 --seed 164363
#
# Fase 1 -- torneios, por (bloco, estrato), a partir da listagem dos blocos:
#   Rscript scripts/sortear_amostra.R torneios --n-por-estrato 2 --seed 164363
#
# Fase 2 -- jogadores, por posicao na lista de resultados dos torneios sorteados
# (m_k = 5 titulares, sem reserva; ADR-010):
#   Rscript scripts/sortear_amostra.R jogadores --m-por-torneio 5 --n-reserva 0 --seed 164363
#
# Torneio extra numa celula (ADR-011): continua a permutacao da celula, sorteia
# as m_k posicoes do novo torneio e acrescenta as linhas em branco a coleta:
#   Rscript scripts/sortear_amostra.R torneio-extra --bloco 5 --estrato low --seed 164363
#
# Top 10 dos torneios sorteados (fora do plano): acrescenta a top10_torneios.csv
# 10 linhas em branco para cada torneio sorteado que ainda nao esta nele:
#   Rscript scripts/sortear_amostra.R top10

suppressPackageStartupMessages(library(optparse))

for (arquivo in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(arquivo)
}

option_list <- list(
  make_option("--inicio", default = "2026-10-17 20:00", help = "Inicio do periodo [%default]"),
  make_option("--fim", default = "2026-10-21 00:00", help = "Fim do periodo, exclusivo [%default]"),
  make_option("--horas-bloco", default = 2L, help = "Duracao de cada bloco, em horas [%default]"),
  make_option("--fuso", default = "America/Sao_Paulo", help = "Fuso dos horarios [%default]"),
  make_option("--n-blocos", default = 6L, help = "Blocos sorteados, b [%default]"),
  make_option("--log", default = "data/raw/sharkscope/log_coleta.csv"),
  make_option("--listagem", default = "data/raw/sharkscope/listagem_torneios.csv"),
  make_option("--torneios", default = "data/raw/sharkscope/torneios_sorteados.csv"),
  make_option("--top10", default = "data/raw/sharkscope/top10_torneios.csv"),
  make_option("--jogadores", default = "data/raw/sharkscope/jogadores_sorteados.csv"),
  make_option("--coleta", default = "data/raw/sharkscope/coleta_jogadores.csv"),
  make_option("--bloco", default = NA_integer_, help = "Bloco da celula (torneio-extra)"),
  make_option("--estrato", default = NA_character_, help = "Estrato da celula (torneio-extra)"),
  make_option("--n-extra", default = 1L, help = "Torneios a acrescentar na celula [%default]"),
  make_option("--n-por-estrato", default = as.integer(Sys.getenv("N_POR_ESTRATO", 2))),
  make_option("--m-por-torneio", default = as.integer(Sys.getenv("M_POR_TORNEIO", 5))),
  make_option("--n-reserva", default = as.integer(Sys.getenv("N_RESERVA", 0))),
  make_option("--seed", default = as.integer(Sys.getenv("RANDOM_SEED", 42)))
)
parser <- OptionParser(
  usage = "%prog [blocos|torneios|jogadores|torneio-extra|top10] [opcoes]",
  option_list = option_list
)
entrada <- parse_args(
  parser,
  positional_arguments = 1, convert_hyphens_to_underscores = TRUE
)
etapa <- entrada$args
args <- entrada$options

if (etapa == "blocos") {
  blocos <- gerar_blocos(args$inicio, args$fim, args$horas_bloco, args$fuso)
  sorteados <- sortear_blocos(blocos, args$n_blocos, args$seed)
  saida <- "data/raw/sharkscope/blocos_sorteados.csv"
  write.csv(sorteados, saida, row.names = FALSE)
  registrar_log_coleta(
    args$log,
    fase = "0", evento = "sorteio_blocos",
    detalhe = sprintf(
      "AASs de b = %d entre B = %d blocos de %d h de %s a %s (%s); sorteados (bloco_id): %s",
      args$n_blocos, nrow(blocos), args$horas_bloco, args$inicio, args$fim, args$fuso,
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
  moldura <- montar_moldura(carregar_listagem(args$listagem))
  sorteados <- sortear_torneios(moldura, args$n_por_estrato, args$seed)
  saida <- "data/raw/sharkscope/torneios_sorteados.csv"
  write.csv(sorteados, saida, row.names = FALSE)
  cat(sprintf("%d torneios sorteados (seed = %d) -> %s\n", nrow(sorteados), args$seed, saida))
} else if (etapa == "jogadores") {
  torneios <- read.csv(args$torneios, colClasses = c(torneio_id = "character"))
  sorteados <- sortear_jogadores(
    torneios[, c("bloco_id", "estrato", "torneio_id", "n_inscritos")],
    args$m_por_torneio, args$n_reserva, args$seed
  )
  saida <- "data/raw/sharkscope/jogadores_sorteados.csv"
  write.csv(sorteados, saida, row.names = FALSE)
  cat(sprintf("%d posicoes sorteadas (seed = %d) -> %s\n", nrow(sorteados), args$seed, saida))
} else if (etapa == "torneio-extra") {
  if (is.na(args$bloco) || is.na(args$estrato)) stop("Informe --bloco e --estrato.")
  moldura <- montar_moldura(carregar_listagem(args$listagem))
  torneios <- read.csv(args$torneios, colClasses = c(torneio_id = "character"))
  estendidos <- estender_torneios(
    moldura, torneios, args$bloco, args$estrato, args$n_extra, args$seed
  )
  novos <- estendidos[-seq_len(nrow(torneios)), , drop = FALSE]
  write.csv(estendidos, args$torneios, row.names = FALSE)

  posicoes <- sortear_jogadores(
    novos[, c("bloco_id", "estrato", "torneio_id", "n_inscritos")],
    args$m_por_torneio, 0, args$seed
  )
  jogadores <- read.csv(args$jogadores, colClasses = c(torneio_id = "character"))
  write.csv(rbind(jogadores, posicoes[, names(jogadores)]), args$jogadores, row.names = FALSE)

  colunas_texto <- c(torneio_id = "character", nickname = "character", data_consulta = "character")
  coleta <- read.csv(args$coleta, colClasses = colunas_texto, fileEncoding = "UTF-8")
  em_branco <- posicoes[, intersect(names(coleta), names(posicoes))]
  em_branco[setdiff(names(coleta), names(em_branco))] <- NA
  em_branco$nickname <- ""
  em_branco$data_consulta <- ""
  saida_coleta <- file(args$coleta, "w", encoding = "UTF-8")
  write.csv(rbind(coleta, em_branco[, names(coleta)]), saida_coleta, row.names = FALSE, na = "")
  close(saida_coleta)

  registrar_log_coleta(
    args$log,
    fase = "1", evento = "torneio_extra",
    detalhe = sprintf(
      paste(
        "Celula (bloco %d, %s): n_jh de %d para %d, continuando a permutacao da celula (ADR-011);",
        "sorteados (torneio_id): %s; %d posicoes por torneio, sem reserva."
      ),
      args$bloco, args$estrato, unique(novos$n_jh) - nrow(novos), unique(novos$n_jh),
      paste(novos$torneio_id, collapse = " "), args$m_por_torneio
    ),
    seed = args$seed
  )
  cat(sprintf(
    "%d torneio(s) e %d posicoes acrescentados (seed = %d) -> %s, %s, %s\n",
    nrow(novos), nrow(posicoes), args$seed, args$torneios, args$jogadores, args$coleta
  ))
  print(posicoes[, c("torneio_id", "n_inscritos", "ordem", "posicao")], row.names = FALSE)
} else if (etapa == "top10") {
  torneios <- read.csv(args$torneios, colClasses = c(torneio_id = "character"))
  existente <- if (file.exists(args$top10)) carregar_top10(args$top10) else NULL
  novos <- torneios[!torneios$torneio_id %in% existente$torneio_id, c("bloco_id", "torneio_id")]
  n_linhas <- 10 * nrow(novos)
  linhas <- data.frame(
    bloco_id = rep(novos$bloco_id, each = 10), torneio_id = rep(novos$torneio_id, each = 10),
    posicao = rep(1:10, times = nrow(novos)), nickname = rep("", n_linhas),
    data_anotacao = rep("", n_linhas), stringsAsFactors = FALSE
  )
  write.csv(rbind(existente, linhas), args$top10, row.names = FALSE, na = "")
  cat(sprintf("%d torneios acrescentados -> %s\n", nrow(novos), args$top10))
} else {
  stop("Etapa invalida: use 'blocos', 'torneios', 'jogadores', 'torneio-extra' ou 'top10'.")
}
