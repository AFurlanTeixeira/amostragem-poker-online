#!/usr/bin/env Rscript
# Estimacao a partir da coleta de campo (SharkScope): ROI medio por jogador e
# proporcao de lucrativos, variancia em tres estagios (blocos -> torneios ->
# jogadores) com EP linearizado e por jackknife de blocos, IC 95%, componentes
# de variancia, EPA (com a parte dos pesos) e sensibilidade a nao resposta.
# Metodologia §7-§9; ADR-014 e ADR-015.
#
# Exemplo:
#   Rscript scripts/estimar_campo.R --unidade jogador

suppressPackageStartupMessages(library(optparse))

for (arquivo in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(arquivo)
}

option_list <- list(
  make_option("--listagem", default = "data/raw/sharkscope/listagem_torneios.csv"),
  make_option("--coleta", default = "data/raw/sharkscope/coleta_jogadores.csv"),
  make_option("--blocos", default = "data/raw/sharkscope/blocos_sorteados.csv"),
  make_option("--unidade", default = "jogador", help = "jogador ou inscricao [%default]"),
  make_option(
    "--excluir",
    default = "",
    help = "Nicknames a retirar da coleta, separados por virgula (sensibilidade)."
  )
)
args <- parse_args(OptionParser(option_list = option_list), convert_hyphens_to_underscores = TRUE)

moldura <- montar_moldura(carregar_listagem(args$listagem))
coleta <- carregar_coleta(args$coleta)
B <- read.csv(args$blocos)$B[1]

excluir <- trimws(strsplit(args$excluir, ",")[[1]])
if (length(excluir) > 0) {
  fora <- coleta$nickname %in% excluir & coleta$respondeu %in% TRUE
  if (sum(fora) == 0) stop("Nenhum respondente com os nicknames de --excluir.", call. = FALSE)
  cat(sprintf("== Sensibilidade: %d respondente(s) excluido(s) ==\n", sum(fora)))
  coleta <- coleta[!fora, , drop = FALSE]
}

# Imprime as parcelas de uma variancia com o percentual do total.
imprimir_parcelas <- function(titulo, parcelas, total) {
  cat(sprintf(
    "%s: %s\n", titulo,
    paste(sprintf("%s %.5g (%.1f%%)", names(parcelas), parcelas, 100 * parcelas / total),
      collapse = " | "
    )
  ))
}

cat("== Nao resposta (perfis privados e Anonimo) ==\n")
print(taxa_nao_resposta(coleta), digits = 3)

for (variavel in c("roi", "lucrativo", "lucrativo_estrito")) {
  res <- estimar_media_tres_estagios(coleta, moldura, B, variavel, unidade = args$unidade)
  epa <- calcular_epa_tres_estagios(res)
  cat(sprintf("\n== %s (por %s; B = %d, b = %d) ==\n", variavel, res$unidade, B, res$b))
  cat(sprintf(
    "Estimativa: %.4f | EP: %.4f | IC 95%%: [%.4f; %.4f] (gl = %d)\n",
    res$estimativa, res$erro_padrao, res$li, res$ls, res$gl
  ))
  if (variavel != "roi") {
    ic <- ic_logit(res)
    cat(sprintf("IC 95%% logit (ADR-012): [%.4f; %.4f]\n", ic[["li"]], ic[["ls"]]))
  }
  cat(sprintf(
    "EPA: %.3f = pesos (1 + CV^2 w) %.3f x resto %.3f | n efetivo de Kish: %.1f de %d\n",
    epa$epa, epa$epa_pesos, epa$epa_conglomerado, epa$n / epa$epa_pesos, epa$n
  ))
  cat(sprintf(
    "  (registro; nao interpretavel, ADR-005) rho_int: %.3f | m medio por torneio: %.2f\n",
    epa$rho_int, epa$m_medio
  ))
  cat(sprintf(
    "Torneios fora (1 respondente, ADR-011): %s\n",
    paste(res$torneios_excluidos, collapse = " ")
  ))

  # Jackknife JK1 de blocos, ao lado da linearizacao (ADR-014).
  jk1 <- montar_resultado(res$estimativa, res$variancia_jk1, gl = res$gl, nivel = 0.95)
  ic_jk1 <- if (variavel == "roi") c(li = jk1$li, ls = jk1$ls) else ic_logit(jk1)
  cat(sprintf(
    "Jackknife JK1 de blocos: EP %.4f | IC 95%% %s: [%.4f; %.4f]\n",
    jk1$erro_padrao, if (variavel == "roi") "t" else "logit", ic_jk1[["li"]], ic_jk1[["ls"]]
  ))
  # Conglomerado ultimo: so o termo entre blocos, sem a correcao (1 - b/B).
  ep_ultimo <- sqrt(B^2 * stats::var(res$blocos_z$Y_j) / res$b) / res$N_hat
  cat(sprintf("Conglomerado ultimo (sem FCPF): EP %.4f\n", ep_ultimo))

  cat("Totais da variavel linearizada por bloco (Z_j) e variancia dentro (v_j):\n")
  print(res$blocos_z, digits = 4)
  imprimir_parcelas("Termos da formula (NAO sao componentes)", res$termos, res$variancia)
  imprimir_parcelas(
    "Componentes nao viesados (negativo = 0)", res$componentes, res$variancia
  )
}

# Sensibilidade a nao resposta (R/nao_resposta.R).
cat("\n== Nao resposta: limites de pior caso (por inscricao) ==\n")
for (variavel in c("lucrativo", "lucrativo_estrito")) {
  lim <- limites_pior_caso(coleta, moldura, B, variavel)
  cat(sprintf(
    "%s: observada %.3f | limites [%.3f; %.3f] | taxa de resposta %.3f\n",
    variavel, lim$observada, lim$inferior, lim$superior, lim$taxa_resposta
  ))
}
cat(sprintf("\n== Nao resposta: ajuste por posicao no torneio (por %s) ==\n", args$unidade))
for (variavel in c("roi", "lucrativo", "lucrativo_estrito")) {
  aj <- ajustar_por_posicao(coleta, moldura, B, variavel, unidade = args$unidade)
  cat(sprintf(
    "%s: sem ajuste %.4f | ajustada %.4f | celulas colapsadas %d\n",
    variavel, aj$sem_ajuste, aj$ajustada, aj$celulas_colapsadas
  ))
}
