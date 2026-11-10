#!/usr/bin/env Rscript
# Analise exploratoria do top 10 dos 24 torneios originais (fora do plano) e
# comparacao com a amostra aleatoria, a estimativa do plano em tres estagios e
# a populacao do Kaggle. Resultados comentados em docs/notas/aed_top10.md.
#
# Exemplo:
#   Rscript scripts/explorar_top10.R

suppressPackageStartupMessages(library(optparse))

for (arquivo in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(arquivo)
}

option_list <- list(
  make_option("--listagem", default = "data/raw/sharkscope/listagem_torneios.csv"),
  make_option("--coleta", default = "data/raw/sharkscope/coleta_jogadores.csv"),
  make_option("--blocos", default = "data/raw/sharkscope/blocos_sorteados.csv"),
  make_option("--top10", default = "data/raw/sharkscope/top10_torneios.csv"),
  make_option("--kaggle", default = Sys.getenv(
    "KAGGLE_PATH", "data/raw/kaggle/poker_tournament_survival.csv"
  ), help = "populacao de referencia; ignorada se o arquivo nao existir [%default]"),
  make_option("--saida-tabelas", default = "data/processed",
    help = "pasta dos CSV (aed_top10_*.csv) [%default]"
  ),
  make_option("--saida-figuras", default = "docs/figuras",
    help = "pasta dos PNG (aed_top10_*.png) [%default]"
  )
)
args <- parse_args(OptionParser(option_list = option_list), convert_hyphens_to_underscores = TRUE)

moldura <- montar_moldura(carregar_listagem(args$listagem))
coleta <- carregar_coleta(args$coleta)
top10 <- preparar_top10(carregar_top10(args$top10), moldura)
B <- read.csv(args$blocos)$B[1]
kaggle <- if (file.exists(args$kaggle)) carregar_populacao_kaggle(args$kaggle, "nenhum")

dir.create(args$saida_tabelas, showWarnings = FALSE, recursive = TRUE)
dir.create(args$saida_figuras, showWarnings = FALSE, recursive = TRUE)

#' Imprime uma tabela e grava em CSV com o prefixo da AED do top 10.
mostrar <- function(tabela, nome, titulo) {
  cat(sprintf("\n== %s ==\n", titulo))
  print(tabela, digits = 4, row.names = FALSE)
  utils::write.csv(tabela, file.path(args$saida_tabelas, sprintf("aed_top10_%s.csv", nome)),
    row.names = FALSE
  )
}

for (por in c("estrato", "posicao")) {
  mostrar(resumir_resposta_top10(top10, por), paste0("resposta_", por),
    sprintf("Top 10: resposta por %s", por)
  )
}
for (v in c("roi", "n_jogos_dia", "lucro")) {
  mostrar(resumir_variavel_estratos(top10, v), paste0("resumo_", v),
    sprintf("Top 10: %s dos respondentes por estrato (sem peso)", v)
  )
}
for (v in c("roi", "lucrativo")) {
  mostrar(decompor_variancia_estratos(top10, v), paste0("decomposicao_", v),
    sprintf("Top 10: decomposicao da SQ de %s (sem peso)", v)
  )
}
mostrar(conferir_reconsultas(top10, coleta), "reconsultas",
  "Posicoes 1-10 sorteadas na amostra: mesmo registro consultado duas vezes"
)

grupos <- montar_grupos_top10(top10, coleta)
mostrar(resumir_grupos_top10(grupos), "grupos", "Top 10 x amostra (posicao > 10), mesmos torneios")
mostrar(resumir_grupos_top10(grupos, por_estrato = TRUE), "grupos_estrato",
  "Top 10 x amostra (posicao > 10), por estrato"
)
por_torneio <- comparar_por_torneio_top10(grupos)
mostrar(por_torneio, "por_torneio", "Comparacao pareada por torneio")
mostrar(testar_top10(grupos, por_torneio, top10), "testes",
  "Testes descritivos (ignoram o plano e a conglomeracao)"
)
referencia <- tabela_referencia_top10(grupos, coleta, moldura, B, kaggle)
mostrar(referencia, "referencia", "Top 10 ao lado dos outros resultados")

plano <- referencia$roi_media[referencia$tipo == "com peso (1/f_i)"]
figuras <- list(
  posicao = list(function() grafico_top10_posicao(top10), 9),
  vs_amostra = list(function() grafico_top10_vs_amostra(grupos, referencia = plano), 7)
)
for (nome in names(figuras)) {
  caminho <- file.path(args$saida_figuras, sprintf("aed_top10_%s.png", nome))
  grDevices::png(caminho, width = figuras[[nome]][[2]], height = 4, units = "in", res = 150)
  figuras[[nome]][[1]]()
  grDevices::dev.off()
  cat(sprintf("Figura: %s\n", caminho))
}
