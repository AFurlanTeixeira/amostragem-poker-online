#!/usr/bin/env Rscript
# Gera docs/fase1_torneios_sorteados.md a partir de torneios_sorteados.csv,
# com nome, horario e formato tirados da listagem. Rode de novo sempre que o
# sorteio de torneios mudar (ex.: novos blocos listados).
#
# Exemplo:
#   Rscript scripts/gerar_md_torneios.R

suppressPackageStartupMessages(library(optparse))

for (arquivo in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(arquivo)
}

option_list <- list(
  make_option("--sorteados", default = "data/raw/sharkscope/torneios_sorteados.csv"),
  make_option("--listagem", default = "data/raw/sharkscope/listagem_torneios.csv"),
  make_option("--blocos", default = "data/raw/sharkscope/blocos_sorteados.csv"),
  make_option("--saida", default = "docs/fase1_torneios_sorteados.md")
)
args <- parse_args(OptionParser(option_list = option_list), convert_hyphens_to_underscores = TRUE)

sorteados <- read.csv(args$sorteados, colClasses = c(torneio_id = "character"))
# Os torneios extras (ADR-011) vem depois dos 2 originais da celula no CSV.
celula <- paste(sorteados$bloco_id, sorteados$estrato)
sorteados$sorteio <- ifelse(
  stats::ave(seq_along(celula), celula, FUN = seq_along) > N_MINIMO_POR_ESTRATO,
  "extra", "original"
)
listagem <- carregar_listagem(args$listagem)
blocos <- read.csv(args$blocos, stringsAsFactors = FALSE)

colunas_listagem <- c("torneio_id", "nome", "inicio_brasilia", "observacao")
m <- merge(sorteados, listagem[, colunas_listagem], by = "torneio_id")
ordem_estrato <- stats::setNames(seq_along(ROTULOS_BUYIN), ROTULOS_BUYIN)
m <- m[order(m$bloco_id, ordem_estrato[m$estrato], m$inicio_brasilia), ]

rotulo <- c(micro = "Micro", low = "Low", mid_high = "Mid/High")
dia <- c("segunda", "terça", "quarta", "quinta", "sexta", "sábado", "domingo")
reais <- function(x) formatC(x, format = "f", digits = 2, decimal.mark = ",")
data_hora <- function(x) sprintf("%s/%s %s", substr(x, 9, 10), substr(x, 6, 7), substr(x, 12, 16))

linhas <- c(
  "# Fase 1 — Torneios sorteados",
  "",
  paste0(
    "Versão em Markdown de [`data/raw/sharkscope/torneios_sorteados.csv`]",
    "(../data/raw/sharkscope/torneios_sorteados.csv), ",
    paste(
      "com o nome, o horário e o formato de cada torneio tirados de",
      "[`listagem_torneios.csv`](../data/raw/sharkscope/listagem_torneios.csv).",
      "O CSV é a fonte oficial; este arquivo é só para leitura e é gerado por",
      "`Rscript scripts/gerar_md_torneios.R`."
    )
  ),
  "",
  paste(
    "Sorteio: AAS sem reposição de $`n_{jh}`$ = 2 torneios por (bloco, estrato),",
    "semente 164363 com sementes derivadas por célula ([`R/sorteio.R`](../R/sorteio.R)).",
    "$`M_k`$ é o total de entradas da fonte, com re-entries",
    "([Metodologia §2.4](Metodologia.md#24-variáveis-de-interesse)). Horários de Brasília."
  ),
  "",
  paste(
    "Torneios extras: nas células que ficaram com menos de 2 torneios com $`m_k \\ge 2`$",
    "respondentes, o próximo torneio da mesma permutação da célula foi sorteado",
    "(`sortear_amostra.R torneio-extra`, [ADR-011](../.ai/modelagem.md)). Eles aparecem",
    "como \"extra\" na coluna Sorteio, e $`n_{jh}`$ é o total sorteado na célula."
  ),
  ""
)
for (id in unique(m$bloco_id)) {
  bl <- blocos[blocos$bloco_id == id, ]
  d <- m[m$bloco_id == id, ]
  linhas <- c(
    linhas,
    sprintf(
      "## Bloco %d — %s a %s (%s)",
      id, data_hora(bl$inicio), substr(bl$fim, 12, 16), dia[bl$dia_semana]
    ),
    "",
    paste(
      "| Estrato | `torneio_id` | Nome | Início | Buy-in (US$) | $`M_k`$ (entradas) |",
      "$`N_{jh}`$ | $`n_{jh}`$ | Formato | Sorteio |"
    ),
    "|---|---|---|---|---:|---:|---:|---:|---|---|",
    sprintf(
      "| %s | %s | %s | %s | %s | %d | %d | %d | %s | %s |",
      rotulo[d$estrato], d$torneio_id, d$nome, substr(d$inicio_brasilia, 12, 16),
      reais(d$buy_in), d$n_inscritos, d$N_jh, d$n_jh, sub("^formato: ", "", d$observacao),
      d$sorteio
    ),
    ""
  )
}

totais <- aggregate(cbind(torneios = 1, entradas = n_inscritos) ~ estrato, data = m, FUN = sum)
totais <- totais[order(ordem_estrato[totais$estrato]), ]
linhas <- c(
  linhas,
  "## Resumo por estrato",
  "",
  "| Estrato | Torneios sorteados | Soma de $`M_k`$ |",
  "|---|---:|---:|",
  sprintf("| %s | %d | %d |", rotulo[totais$estrato], totais$torneios, totais$entradas),
  sprintf("| **Total** | **%d** | **%d** |", sum(totais$torneios), sum(totais$entradas))
)

writeLines(enc2utf8(linhas), args$saida, useBytes = TRUE)
cat(sprintf("%d torneios -> %s\n", nrow(m), args$saida))
