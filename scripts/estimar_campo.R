#!/usr/bin/env Rscript
# Estimacao a partir da coleta de campo (SharkScope): ROI medio por jogador e
# proporcao de lucrativos, variancia em tres estagios (blocos -> torneios ->
# jogadores), IC 95%, EPA e rho_int. Metodologia §7-§9.
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
  make_option("--unidade", default = "jogador", help = "jogador ou inscricao [%default]")
)
args <- parse_args(OptionParser(option_list = option_list), convert_hyphens_to_underscores = TRUE)

moldura <- montar_moldura(carregar_listagem(args$listagem))
coleta <- carregar_coleta(args$coleta)
B <- read.csv(args$blocos)$B[1]

cat("== Nao resposta (perfis privados e Anonimo) ==\n")
print(taxa_nao_resposta(coleta), digits = 3)

for (variavel in c("roi", "lucrativo")) {
  res <- estimar_media_tres_estagios(coleta, moldura, B, variavel, unidade = args$unidade)
  epa <- calcular_epa_tres_estagios(res)
  cat(sprintf("\n== %s (por %s; B = %d, b = %d) ==\n", variavel, res$unidade, B, res$b))
  cat(sprintf(
    "Estimativa: %.4f | EP: %.4f | IC 95%%: [%.4f; %.4f] (gl = %d)\n",
    res$estimativa, res$erro_padrao, res$li, res$ls, res$gl
  ))
  cat(sprintf("EPA: %.3f | rho_int: %.3f | m medio: %.2f\n", epa$epa, epa$rho_int, epa$m_medio))
  print(res$blocos, digits = 4)
}
