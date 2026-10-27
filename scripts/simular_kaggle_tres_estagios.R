#!/usr/bin/env Rscript
# Plano de campo em tres estagios aplicado ao dataset do Kaggle (ADR-013):
# populacao sintetica com a estrutura do campo, sorteio "oficial" passo a
# passo (com a nao resposta do campo e a regra de torneios extras) e Monte
# Carlo do plano para varios b.
#
# Exemplo:
#   Rscript scripts/simular_kaggle_tres_estagios.R --n-rep 5000 --b 4,6,12 --seed 164363

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
  make_option("--coleta", default = "data/raw/sharkscope/coleta_jogadores.csv"),
  make_option("--B", default = 38L, help = "Blocos na populacao sintetica [%default]"),
  make_option("--b-oficial", default = 6L, help = "Blocos no sorteio oficial [%default]"),
  make_option("--b", default = "4,6,12", help = "Blocos por replica no Monte Carlo [%default]"),
  make_option("--n-rep", default = 5000L, help = "Replicas por valor de b [%default]"),
  make_option("--seed", default = 164363L, help = "Semente (a do campo) [%default]")
)
args <- parse_args(OptionParser(option_list = option_list), convert_hyphens_to_underscores = TRUE)
saida <- function(nome) file.path("data/processed", sprintf("kaggle_tres_estagios_%s.csv", nome))
dir.create("data/processed", showWarnings = FALSE)

# 1. Populacao sintetica com a estrutura do campo.
kaggle <- carregar_populacao_kaggle(args$data_path, "buyin")
moldura_campo <- montar_moldura(carregar_listagem(args$listagem))
pop <- montar_populacao_blocos(kaggle, moldura_campo, args$B, args$seed)
verdade <- parametros_verdadeiros(pop)
cat(sprintf(
  "== Populacao sintetica (seed = %d) ==\n%d blocos, %d torneios, %d inscricoes, %s\n",
  args$seed, args$B, nrow(pop$torneios), nrow(pop$inscricoes),
  sprintf("%d jogadores distintos", nrow(pop$jogadores))
))
print(table(pop$torneios$estrato))
cat("f_i por jogador:\n")
print(summary(pop$jogadores$f_i))
cat("\nParametros verdadeiros:\n")
print(verdade, digits = 5)
write.csv(verdade, saida("parametros"), row.names = FALSE)

# 2. Sorteio oficial: mesma seed e tamanhos do campo, nao resposta com as
# taxas observadas por estrato e regra de torneios extras (ADR-011).
nr <- taxa_nao_resposta(carregar_coleta(args$coleta))
taxas <- stats::setNames(nr$taxa_nao_resposta, nr$estrato)
amostra <- sortear_amostra_kaggle(pop, args$b_oficial, 2, 5, args$seed, taxas)
amostra <- aplicar_torneios_extras(pop, amostra, 5, args$seed, taxas)
cat(sprintf(
  "\n== Sorteio oficial: b = %d (blocos na ordem do sorteio: %s) ==\n",
  args$b_oficial, paste(amostra$blocos, collapse = " ")
))
cat("Taxas de nao resposta simuladas (as do campo):\n")
print(round(taxas, 3))
cat(sprintf(
  "Torneios: %d (%d extras) | posicoes: %d | respondentes: %d\n",
  nrow(amostra$sorteados), sum(amostra$eventos$evento == "torneio_extra"),
  nrow(amostra$coleta), sum(amostra$coleta$respondeu)
))
if (!is.null(amostra$eventos)) print(amostra$eventos, row.names = FALSE)
write.csv(amostra$coleta, saida("coleta_oficial"), row.names = FALSE)

oficial <- do.call(rbind, lapply(c("jogador", "inscricao"), function(u) {
  do.call(rbind, lapply(c("roi", "lucrativo"), function(v) {
    res <- estimar_media_tres_estagios(amostra$coleta, amostra$moldura, args$B, v, unidade = u)
    epa <- calcular_epa_tres_estagios(res)
    ic <- if (v == "roi") c(li = NA, ls = NA) else ic_logit(res)
    data.frame(
      unidade = u, variavel = v,
      parametro = verdade$valor[verdade$unidade == u & verdade$variavel == v],
      estimativa = res$estimativa, erro_padrao = res$erro_padrao, gl = res$gl,
      li = res$li, ls = res$ls, li_logit = ic[["li"]], ls_logit = ic[["ls"]],
      epa = epa$epa, rho_int = epa$rho_int, m_medio = epa$m_medio,
      excluidos = length(res$torneios_excluidos)
    )
  }))
}))
print(oficial, digits = 4, row.names = FALSE)
write.csv(oficial, saida("sorteio_oficial"), row.names = FALSE)

# 3. Monte Carlo do plano (sem nao resposta) para cada b.
valores_b <- as.integer(strsplit(args$b, ",")[[1]])
sims <- do.call(rbind, lapply(valores_b, function(b) {
  cat(sprintf("\nMonte Carlo: b = %d, %d replicas...\n", b, args$n_rep))
  simular_tres_estagios(pop, b, args$n_rep, args$seed)
}))
resumo <- resumir_tres_estagios(sims, verdade)
cat("\n== Monte Carlo ==\n")
print(resumo, digits = 4, row.names = FALSE)
write.csv(resumo, saida("monte_carlo"), row.names = FALSE)
