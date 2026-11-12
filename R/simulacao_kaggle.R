#' Simulacao de Monte Carlo dos planos de amostragem direta sobre o dataset
#' do Kaggle (populacao conhecida; Metodologia §10).
#'
#' Como o parametro verdadeiro e conhecido, o vies, a variancia, o EQM e a
#' cobertura do IC de cada plano sao medidos empiricamente.

#' Alocacao proporcional do tamanho de amostra entre estratos.
#'
#' n_h proporcional a N_h, com pelo menos 2 (para estimar s_h^2) e no maximo
#' N_h por estrato. O arredondamento e pelos maiores restos, para que
#' sum(n_h) = n e a comparacao com a AAS seja de mesmo n.
#'
#' @param N_h numeric nomeado por estrato.
#' @param n integer, tamanho total da amostra.
#' @return integer nomeado por estrato.
alocacao_proporcional <- function(N_h, n) {
  arredondar_alocacao(n * N_h / sum(N_h), N_h, n)
}

#' Arredonda uma alocacao fracionaria para inteiros que somam `n`.
#'
#' Parte de floor(alvo) limitado a [2, N_h] e ajusta uma unidade por vez no
#' estrato de maior (ou menor) resto ate a soma ser `n`.
#'
#' @param alvo numeric, tamanhos fracionarios por estrato (somam `n`).
#' @param N_h numeric nomeado por estrato.
#' @param n integer, tamanho total da amostra.
#' @return integer nomeado por estrato.
arredondar_alocacao <- function(alvo, N_h, n) {
  if (any(N_h < N_MINIMO_POR_ESTRATO)) {
    stop(sprintf("Todo estrato precisa de N_h >= %d.", N_MINIMO_POR_ESTRATO), call. = FALSE)
  }
  n_minimo <- N_MINIMO_POR_ESTRATO * length(N_h)
  if (n < n_minimo || n > sum(N_h)) {
    stop(
      sprintf("n = %s fora do intervalo [%d, %s] da alocacao.", n, n_minimo, sum(N_h)),
      call. = FALSE
    )
  }
  n_h <- pmin(pmax(floor(alvo), N_MINIMO_POR_ESTRATO), N_h)
  while (sum(n_h) < n) {
    pode <- n_h < N_h
    h <- which(pode)[which.max((alvo - n_h)[pode])]
    n_h[h] <- n_h[h] + 1
  }
  while (sum(n_h) > n) {
    pode <- n_h > N_MINIMO_POR_ESTRATO
    h <- which(pode)[which.min((alvo - n_h)[pode])]
    n_h[h] <- n_h[h] - 1
  }
  stats::setNames(as.integer(n_h), names(N_h))
}

#' Alocacao otima de Neyman (Cochran, 1977, §5.5).
#'
#' n_h proporcional a N_h S_h, com pelo menos 2 e no maximo N_h por estrato.
#' O arredondamento e pelos maiores restos, para que sum(n_h) = n e a
#' comparacao com a AAS seja de mesmo n. Usa os S_h verdadeiros da populacao
#' do Kaggle, entao mede o ganho maximo; em campo, S_h teria de vir de um
#' estudo anterior.
#'
#' @param N_h numeric nomeado por estrato.
#' @param S_h numeric nomeado por estrato, desvio-padrao no estrato.
#' @param n integer, tamanho total da amostra.
#' @return integer nomeado por estrato.
alocacao_neyman <- function(N_h, S_h, n) {
  S_h <- S_h[names(N_h)]
  arredondar_alocacao(n * N_h * S_h / sum(N_h * S_h), N_h, n)
}

#' Roda `n_rep` replicas de AAS e (se houver `estrato`) AAS estratificada
#' com alocacao proporcional e de Neyman.
#'
#' A amostra de Neyman e sorteada com semente derivada da replica, para nao
#' mudar o fluxo aleatorio (e os resultados) da AAS e da proporcional.
#'
#' @param populacao data.frame (ver `carregar_populacao_kaggle()`).
#' @param variavel character, coluna analisada (`"roi"` ou `"lucrativo"`).
#' @param n integer, tamanho de amostra (mesmo do campo, para comparar).
#' @param n_rep integer, numero de replicas de Monte Carlo.
#' @param seed integer, semente.
#' @param nivel numeric, nivel de confianca do IC.
#' @return data.frame com uma linha por replica e plano: `replica`, `plano`,
#'   `estimativa`, `variancia`, `li`, `ls`.
simular_planos <- function(populacao, variavel, n, n_rep, seed, nivel = 0.95) {
  y <- populacao[[variavel]]
  N <- length(y)
  tem_estrato <- "estrato" %in% names(populacao)
  if (tem_estrato) {
    N_h <- table(populacao$estrato)
    N_h <- stats::setNames(as.numeric(N_h), names(N_h))
    n_h <- alocacao_proporcional(N_h, n)
    S_h <- tapply(y, populacao$estrato, stats::sd)
    n_h_neyman <- alocacao_neyman(N_h, stats::setNames(as.numeric(S_h), names(S_h)), n)
    indices_por_estrato <- split(seq_len(N), populacao$estrato)[names(N_h)]
    estratificada <- function(tamanhos) {
      amostra <- unlist(lapply(names(N_h), function(h) {
        idx <- indices_por_estrato[[h]]
        idx[sample.int(length(idx), tamanhos[[h]])]
      }))
      estimar_media_estratificada(y[amostra], populacao$estrato[amostra], N_h, nivel = nivel)
    }
  }

  withr_seed(seed, {
    replicas <- lapply(seq_len(n_rep), function(r) {
      aas <- estimar_media_aas(y[sample.int(N, n)], N, nivel = nivel)
      linhas <- list(linha_simulacao(r, "AAS", aas))
      if (tem_estrato) {
        prop <- estratificada(n_h)
        ney <- withr_seed(semente_derivada(seed + r, "neyman"), estratificada(n_h_neyman))
        linhas <- c(linhas, list(
          linha_simulacao(r, "AAS estratificada (proporcional)", prop),
          linha_simulacao(r, "AAS estratificada (Neyman)", ney)
        ))
      }
      do.call(rbind, linhas)
    })
  })
  do.call(rbind, replicas)
}

#' Resume as replicas: vies, variancia empirica, EQM, cobertura e EPA.
#'
#' O EPA empirico de cada plano usa a variancia de Monte Carlo da AAS como
#' referencia (Bolfarine & Bussab §3.4 e §4.3.4).
#'
#' @param simulacoes data.frame de `simular_planos()`.
#' @param parametro numeric, valor verdadeiro na populacao.
#' @return data.frame com uma linha por plano.
resumir_simulacao <- function(simulacoes, parametro) {
  planos <- unique(simulacoes$plano)
  resumo <- do.call(rbind, lapply(planos, function(p) {
    s <- simulacoes[simulacoes$plano == p, ]
    data.frame(
      plano = p,
      media_estimativas = mean(s$estimativa),
      vies = mean(s$estimativa) - parametro,
      variancia_mc = stats::var(s$estimativa),
      media_var_estimada = mean(s$variancia),
      eqm = mean((s$estimativa - parametro)^2),
      cobertura = mean(s$li <= parametro & parametro <= s$ls),
      stringsAsFactors = FALSE
    )
  }))
  resumo$epa_empirico <- resumo$variancia_mc / resumo$variancia_mc[resumo$plano == "AAS"]
  resumo
}

#' Converte o resultado de um estimador em uma linha de data.frame.
#'
#' @param replica integer.
#' @param plano character.
#' @param resultado lista de `montar_resultado()`.
#' @return data.frame de uma linha.
linha_simulacao <- function(replica, plano, resultado) {
  data.frame(
    replica = replica,
    plano = plano,
    estimativa = resultado$estimativa,
    variancia = resultado$variancia,
    li = resultado$li,
    ls = resultado$ls,
    stringsAsFactors = FALSE
  )
}
