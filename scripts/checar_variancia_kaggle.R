#!/usr/bin/env Rscript
# Checagens da variancia em tres estagios na populacao sintetica do Kaggle
# (ADR-013 e ADR-014), onde tudo e conhecido:
#   1. a variancia estimada dos TOTAIS (sem razao nem linearizacao) contra a
#      variancia de Monte Carlo, e o CV de N-chapeu;
#   2. os componentes de variancia estimados (`componentes`) contra os
#      componentes verdadeiros, calculados na populacao, ao lado da fracao do
#      1o termo da formula.
# A variavel e z = (ROI - R)/f com R e f verdadeiros, entao nao ha razao.
#
# Exemplo:
#   Rscript scripts/checar_variancia_kaggle.R --b 4 --n-rep 2000

suppressPackageStartupMessages(library(optparse))

for (arquivo in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(arquivo)
}

option_list <- list(
  make_option(
    "--data-path",
    default = Sys.getenv("KAGGLE_PATH", "data/raw/kaggle/poker_tournament_survival.csv")
  ),
  make_option("--listagem", default = "data/raw/sharkscope/listagem_torneios.csv"),
  make_option("--B", default = 38L, help = "Blocos na populacao sintetica [%default]"),
  make_option("--b", default = 4L, help = "Blocos por replica [%default]"),
  make_option("--n-jh", default = 2L, help = "Torneios por celula [%default]"),
  make_option("--m-k", default = 5L, help = "Jogadores por torneio [%default]"),
  make_option("--n-rep", default = 2000L, help = "Replicas [%default]"),
  make_option("--seed", default = 164363L, help = "Semente (a do campo) [%default]")
)
args <- parse_args(OptionParser(option_list = option_list), convert_hyphens_to_underscores = TRUE)

kaggle <- carregar_populacao_kaggle(args$data_path, "buyin")
moldura_campo <- montar_moldura(carregar_listagem(args$listagem))
pop <- montar_populacao_blocos(kaggle, moldura_campo, args$B, args$seed)
ins <- pop$inscricoes
tor <- pop$torneios
B <- args$B
b <- args$b
n_jh <- args$n_jh
m <- args$m_k

# Componentes verdadeiros da variancia do total de `z` (um valor por
# inscricao da populacao), pelas formulas de Cochran (1977, cap. 10-11).
componentes_verdadeiros <- function(z) {
  id <- as.character(tor$torneio_id)
  S2 <- tapply(z, ins$torneio_id, stats::var)[id]
  total_k <- tapply(z, ins$torneio_id, sum)[id]
  M <- tor$n_inscritos
  celula <- paste(tor$bloco_id, tor$estrato)
  N <- tapply(celula, celula, length)
  V <- M^2 * (1 - m / M) * S2 / m
  S2_totais <- tapply(total_k, celula, stats::var)
  c(
    entre_blocos = B^2 * (1 - b / B) * stats::var(tapply(total_k, tor$bloco_id, sum)) / b,
    entre_torneios = (B / b) * sum(N^2 * (1 - n_jh / N) * S2_totais / n_jh),
    dentro_torneios = (B / b) * sum((N / n_jh) * tapply(V, celula, sum))
  )
}

for (u in c("jogador", "inscricao")) {
  f_pop <- if (u == "jogador") ins$f_i else rep(1, nrow(ins))
  N_verdadeiro <- sum(1 / f_pop)
  R <- sum(ins$roi / f_pop) / N_verdadeiro
  verdade <- componentes_verdadeiros((ins$roi - R) / f_pop)

  replicas <- t(sapply(seq_len(args$n_rep), function(r) {
    amostra <- sortear_amostra_kaggle(pop, b, n_jh, m, args$seed + r)
    resp <- amostra$coleta[amostra$coleta$respondeu %in% TRUE, ]
    N_jh <- table(paste(amostra$moldura$bloco_id, amostra$moldura$estrato, sep = "|"))
    f <- if (u == "jogador") resp$f_i else rep(1, nrow(resp))
    z <- total_tres_estagios(resp, (resp$roi - R) / f, N_jh, B)
    den <- total_tres_estagios(resp, 1 / f, N_jh, B)
    c(
      z$componentes,
      total_z = z$total, var_z = z$variancia, termo_1 = z$termos[["entre_blocos"]],
      total_n = den$total, var_n = den$variancia
    )
  }))

  cat(sprintf("\n== Por %s: b = %d, m_k = %d, %d replicas ==\n", u, b, m, args$n_rep))
  cat(sprintf(
    "Totais: Var estimada / Var_MC = %.3f (Z) e %.3f (N) | CV de N-chapeu = %.3f\n",
    mean(replicas[, "var_z"]) / stats::var(replicas[, "total_z"]),
    mean(replicas[, "var_n"]) / stats::var(replicas[, "total_n"]),
    stats::sd(replicas[, "total_n"]) / mean(replicas[, "total_n"])
  ))
  cat("Componentes da variancia do total de z, como fracao da variancia verdadeira:\n")
  print(rbind(
    verdadeiro = verdade / sum(verdade),
    estimado_medio = colMeans(replicas[, names(verdade)]) / sum(verdade)
  ), digits = 3)
  cat(sprintf(
    "1o termo da formula / variancia estimada (medias): %.3f\n",
    mean(replicas[, "termo_1"]) / mean(replicas[, "var_z"])
  ))
}
