#!/usr/bin/env Rscript
# Estimacao a partir da coleta de campo (SharkScope): ROI medio e proporcao
# de lucrativos, variancia em dois estagios, IC 95%, EPA e rho_int.
# Plano §4.2-4.4.
#
# Exemplo:
#   Rscript scripts/estimar_campo.R --metodo auto

suppressPackageStartupMessages(library(optparse))

for (arquivo in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(arquivo)
}

option_list <- list(
  make_option("--moldura", default = "data/raw/sharkscope/moldura_torneios.csv"),
  make_option("--coleta", default = "data/raw/sharkscope/coleta_jogadores.csv"),
  make_option("--metodo", default = "auto", help = "auto, nao_viesado ou razao.")
)
args <- parse_args(OptionParser(option_list = option_list), convert_hyphens_to_underscores = TRUE)

moldura <- carregar_moldura(args$moldura)
coleta <- carregar_coleta(args$coleta)

cat("== Nao resposta (perfis privados) ==\n")
print(taxa_nao_resposta(coleta), digits = 3)

for (variavel in c("roi", "lucrativo")) {
  res <- estimar_media_dois_estagios(coleta, moldura, variavel, metodo = args$metodo)
  epa <- calcular_epa(res, coleta, moldura, variavel)
  cat(sprintf(
    "\n== %s (%s) ==\nEstimativa: %.4f | EP: %.4f | IC 95%%: [%.4f; %.4f] (gl = %d)\n",
    variavel, res$metodo, res$estimativa, res$erro_padrao, res$li, res$ls, res$gl
  ))
  cat(sprintf("EPA: %.3f | rho_int: %.3f | m medio: %.2f\n", epa$epa, epa$rho_int, epa$m_medio))
  print(res$componentes, digits = 4)
}
