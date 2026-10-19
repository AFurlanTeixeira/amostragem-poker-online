#' Simulacao de Monte Carlo dos planos de amostragem direta sobre o dataset
#' do Kaggle (populacao conhecida, plano §2.1 e §4.5).
#'
#' Como o parametro verdadeiro e conhecido, o vies, a variancia, o EQM e a
#' cobertura do IC de cada plano sao medidos empiricamente.

#' Alocacao proporcional do tamanho de amostra entre estratos.
#'
#' n_h = round(n N_h / N), com pelo menos 2 por estrato (para estimar s_h^2).
#'
#' @param N_h numeric nomeado por estrato.
#' @param n integer, tamanho total da amostra.
#' @return integer nomeado por estrato.
alocacao_proporcional <- function(N_h, n) {
  n_h <- pmax(round(n * N_h / sum(N_h)), N_MINIMO_POR_ESTRATO)
  stats::setNames(as.integer(pmin(n_h, N_h)), names(N_h))
}

#' Roda `n_rep` replicas de AAS e (se houver `estrato`) AAS estratificada.
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
    indices_por_estrato <- split(seq_len(N), populacao$estrato)[names(N_h)]
  }

  withr_seed(seed, {
    replicas <- lapply(seq_len(n_rep), function(r) {
      aas <- estimar_media_aas(y[sample.int(N, n)], N, nivel = nivel)
      linhas <- list(linha_simulacao(r, "AAS", aas))
      if (tem_estrato) {
        amostra <- unlist(lapply(names(N_h), function(h) {
          idx <- indices_por_estrato[[h]]
          idx[sample.int(length(idx), n_h[[h]])]
        }))
        ae <- estimar_media_estratificada(
          y[amostra], populacao$estrato[amostra], N_h,
          nivel = nivel
        )
        linhas <- c(linhas, list(linha_simulacao(r, "AAS estratificada", ae)))
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
