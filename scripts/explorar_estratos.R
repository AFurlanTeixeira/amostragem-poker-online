#!/usr/bin/env Rscript
# Analise exploratoria dos estratos de buy-in na coleta de campo (SharkScope):
# moldura, nao resposta, distribuicao do ROI, estimativas por estrato
# (dominio, tres estagios), decomposicao da variancia e top 10.
# Resultados comentados em docs/notas/aed_estratos.md.
#
# Exemplo:
#   Rscript scripts/explorar_estratos.R

suppressPackageStartupMessages(library(optparse))

for (arquivo in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(arquivo)
}

option_list <- list(
  make_option("--listagem", default = "data/raw/sharkscope/listagem_torneios.csv"),
  make_option("--coleta", default = "data/raw/sharkscope/coleta_jogadores.csv"),
  make_option("--blocos", default = "data/raw/sharkscope/blocos_sorteados.csv"),
  make_option("--top10", default = "data/raw/sharkscope/top10_torneios.csv"),
  make_option("--unidade", default = "jogador", help = "jogador ou inscricao [%default]"),
  make_option("--saida-tabelas", default = "data/processed",
    help = "pasta dos CSV (aed_estratos_*.csv) [%default]"
  ),
  make_option("--saida-figuras", default = "docs/figuras",
    help = "pasta dos PNG (aed_estratos_*.png) [%default]"
  )
)
args <- parse_args(OptionParser(option_list = option_list), convert_hyphens_to_underscores = TRUE)

moldura <- montar_moldura(carregar_listagem(args$listagem))
coleta <- carregar_coleta(args$coleta)
top10 <- carregar_top10(args$top10)
B <- read.csv(args$blocos)$B[1]

dir.create(args$saida_tabelas, showWarnings = FALSE, recursive = TRUE)
dir.create(args$saida_figuras, showWarnings = FALSE, recursive = TRUE)

#' Imprime uma tabela e grava em CSV com o prefixo da AED.
mostrar <- function(tabela, nome, titulo) {
  cat(sprintf("\n== %s ==\n", titulo))
  print(tabela, digits = 4, row.names = FALSE)
  utils::write.csv(tabela, file.path(args$saida_tabelas, sprintf("aed_estratos_%s.csv", nome)),
    row.names = FALSE
  )
}

mostrar(resumir_moldura_estratos(moldura), "moldura", "Moldura por estrato")
mostrar(tabela_celulas(moldura, coleta), "celulas", "Celulas bloco x estrato")
mostrar(taxa_nao_resposta(coleta), "nao_resposta", "Nao resposta (amostra aleatoria)")

for (v in c("roi", "n_jogos_dia", "lucro")) {
  mostrar(resumir_variavel_estratos(coleta, v), paste0("resumo_", v),
    sprintf("%s dos respondentes, sem peso", v)
  )
}

for (v in c("roi", "lucrativo", "lucrativo_estrito")) {
  mostrar(estimar_dominios_estratos(coleta, moldura, B, v, args$unidade),
    paste0("dominios_", v), sprintf("%s por estrato (dominio, por %s)", v, args$unidade)
  )
}

# Sensibilidade: o maior ROI (cauda do mid_high) tratado como nao resposta.
maior <- which.max(ifelse(coleta$respondeu %in% TRUE, coleta$roi, -Inf))
sem_maior <- coleta
sem_maior$respondeu[maior] <- FALSE
cat(sprintf(
  "\nSensibilidade: sem o maior ROI (%s, %.1f%%, estrato %s)\n",
  coleta$nickname[maior], coleta$roi[maior], coleta$estrato[maior]
))
mostrar(estimar_dominios_estratos(sem_maior, moldura, B, "roi", args$unidade),
  "dominios_roi_sem_maior", "ROI por estrato sem o maior ROI"
)

for (v in c("roi", "lucrativo")) {
  mostrar(decompor_variancia_estratos(coleta, v), paste0("decomposicao_", v),
    sprintf("Decomposicao da SQ de %s (sem peso)", v)
  )
}
mostrar(decompor_variancia_estratos(sem_maior, "roi"), "decomposicao_roi_sem_maior",
  "Decomposicao da SQ do ROI sem o maior ROI"
)
mostrar(associar_buyin(coleta, moldura, "roi"), "associacao_roi",
  "Associacao do ROI com o buy-in (descritiva, ignora o plano)"
)

comparacao <- comparar_top10_estratos(coleta, top10, moldura)
mostrar(comparacao, "top10", "Amostra aleatoria x top 10 (mesmos torneios)")

figuras <- list(
  moldura = function() grafico_moldura_estratos(moldura),
  roi = function() grafico_roi_estratos(coleta),
  resposta = function() grafico_resposta_estratos(comparacao)
)
larguras <- c(moldura = 9, roi = 6, resposta = 6)
for (nome in names(figuras)) {
  caminho <- file.path(args$saida_figuras, sprintf("aed_estratos_%s.png", nome))
  grDevices::png(caminho, width = larguras[[nome]], height = 4, units = "in", res = 150)
  figuras[[nome]]()
  grDevices::dev.off()
  cat(sprintf("Figura: %s\n", caminho))
}
