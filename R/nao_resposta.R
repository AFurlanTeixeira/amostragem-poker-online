#' Sensibilidade das estimativas de campo a nao resposta (55% das posicoes).
#'
#' Duas analises, ambas descritivas e sem variancia propria:
#' - limites de pior caso (Manski, 1989): os nao respondentes recebem 0 e
#'   depois 1 na variavel binaria;
#' - ajuste por classes de posicao no torneio dentro da celula (bloco x
#'   estrato), com fator de taxa de resposta (classes de ajuste de peso;
#'   Lohr, 2022, cap. 8). A posicao e conhecida tambem para quem nao respondeu.
#' A correcao do plano (M_k/m_k) supoe nao resposta aleatoria dentro do
#' torneio (ADR-006); estas analises medem quanto isso pesa.

#' Limites de pior caso para uma proporcao.
#'
#' Todas as posicoes consultadas entram como respondentes, e a variavel dos
#' nao respondentes vira 0 (limite inferior) ou 1 (superior). E feito por
#' inscricao (f_i = 1), porque `n_jogos_dia` dos nao respondentes e
#' desconhecido. Torneios com 0 ou 1 respondente voltam a entrar, ja que
#' todas as suas posicoes passam a ter valor. Por isso os limites usam mais
#' torneios (e outros n_jh) do que `observada`, que segue a regra do
#' ADR-011: em geral ela fica entre os limites, mas isso nao e garantido.
#'
#' @param coleta data.frame (ver `carregar_coleta()`); linhas com
#'   `respondeu` ausente (nao consultadas) ficam de fora.
#' @param moldura data.frame (ver `montar_moldura()`).
#' @param B numeric, blocos na moldura temporal.
#' @param variavel character, `"lucrativo"` ou `"lucrativo_estrito"`.
#' @return lista com `inferior`, `superior`, `observada` (estimativa por
#'   inscricao so com os respondentes) e `taxa_resposta` (sem peso).
limites_pior_caso <- function(coleta, moldura, B, variavel = "lucrativo") {
  consultadas <- coleta[!is.na(coleta$respondeu), , drop = FALSE]
  limite <- function(valor) {
    d <- consultadas
    d[[variavel]][!d$respondeu] <- valor
    d$respondeu <- TRUE
    estimar_media_tres_estagios(d, moldura, B, variavel, unidade = "inscricao")$estimativa
  }
  list(
    inferior = limite(0),
    superior = limite(1),
    observada = estimar_media_tres_estagios(
      consultadas, moldura, B, variavel, unidade = "inscricao"
    )$estimativa,
    taxa_resposta = mean(consultadas$respondeu)
  )
}

#' Estimativa com ajuste da nao resposta por classe de posicao.
#'
#' Classes: metade de cima (posicao/M_k <= `corte`) e metade de baixo do
#' torneio, dentro de cada celula. Cada respondente recebe o fator
#' a = r_celula / r_classe, com as taxas calculadas sobre as posicoes
#' consultadas, e R_aj = sum(w a y) / sum(w a), com os pesos finais `w` do
#' plano. Se uma classe nao tem respondente na celula, as classes da celula
#' sao juntadas (a = 1).
#'
#' E uma heuristica de sensibilidade, nao o ajuste canonico por classes: o
#' fator multiplica um peso que ja corrige a nao resposta por torneio
#' (M_k / m_k), em vez de substituir essa correcao, e as taxas incluem as
#' posicoes dos torneios que ficaram fora da estimacao (ADR-015).
#'
#' @inheritParams limites_pior_caso
#' @param variavel character, `"roi"`, `"lucrativo"` ou `"lucrativo_estrito"`.
#' @param unidade character, como em `estimar_media_tres_estagios()`.
#' @param corte numeric, posicao relativa que separa as duas classes.
#' @return lista com `sem_ajuste`, `ajustada` e `celulas_colapsadas`.
ajustar_por_posicao <- function(coleta, moldura, B, variavel = "roi",
                                unidade = c("jogador", "inscricao"), corte = 0.5) {
  unidade <- match.arg(unidade)
  validar_colunas(coleta, "posicao", "coleta (ajuste por posicao)")
  res <- estimar_media_tres_estagios(coleta, moldura, B, variavel, unidade = unidade)
  a <- res$amostra

  consultadas <- coleta[!is.na(coleta$respondeu), , drop = FALSE]
  celula <- paste(consultadas$bloco_id, consultadas$estrato, sep = "|")
  classe <- ifelse(consultadas$posicao / consultadas$n_inscritos <= corte, "cima", "baixo")
  taxa_celula <- tapply(consultadas$respondeu, celula, mean)
  taxa_classe <- tapply(consultadas$respondeu, paste(celula, classe), mean)
  colapsar <- names(taxa_celula)[
    tapply(taxa_classe[paste(celula, classe)] == 0, celula, any)[names(taxa_celula)]
  ]

  classe_a <- ifelse(a$posicao_relativa <= corte, "cima", "baixo")
  fator <- as.numeric(taxa_celula[a$celula] / taxa_classe[paste(a$celula, classe_a)])
  fator[a$celula %in% colapsar] <- 1

  list(
    sem_ajuste = res$estimativa,
    ajustada = sum(a$w * fator * a$y) / sum(a$w * fator),
    celulas_colapsadas = length(colapsar)
  )
}
