#' Estimadores da amostragem estratificada em tres estagios (coleta de campo).
#'
#' Plano executado (Metodologia §4): blocos de tempo (UPA, AAS de b entre B)
#' -> torneios (USA, AAS de n_jh entre N_jh em cada celula bloco x estrato)
#' -> jogadores (UTA, AAS de m_k entre M_k). A estratificacao por buy-in e
#' feita dentro de cada bloco e nao e estagio.
#'
#' Referencias: Cochran (1977), cap. 10-11 (variancia por estagios);
#' Thompson (2012), cap. 13 (eq. 13.1-13.8, estimador razao, p. 175);
#' Lohr (2022), cap. 9 (linearizacao do estimador razao). Por jogador
#' distinto, cada inscricao recebe o peso de multiplicidade 1/f_i
#' (Metodologia §14).

# Duracao do periodo de referencia em dias (17/10 20:00 a 21/10 00:00, 76 h).
DIAS_PERIODO <- 76 / 24

#' Frequencia aproximada de inscricoes do jogador no periodo de referencia.
#'
#' f_i = n_jogos_dia * 76/24, com minimo 1: o jogador sorteado jogou ao menos
#' o torneio em que foi sorteado. `n_jogos_dia` vem da janela do ROI (1 ano),
#' entao f_i e uma aproximacao (Metodologia §2.1).
#'
#' @param n_jogos_dia numeric, media de jogos por dia mostrada pelo SharkScope.
#' @return numeric.
frequencia_no_periodo <- function(n_jogos_dia) {
  pmax(1, n_jogos_dia * DIAS_PERIODO)
}

#' Total estimado e variancia nao viesada sob o plano de tres estagios.
#'
#' Ŷ = (B/b) sum_j Ŷ_j, Ŷ_j = sum_h (N_jh/n_jh) sum_k M_k ybar_k
#' (Metodologia §7.1-7.4). Variancia (Metodologia §8.1; Cochran cap. 11):
#' B^2 (1 - b/B) s_u^2 / b + (B/b) sum_j Var(Ŷ_j), com Var(Ŷ_j) somando, por
#' celula, os termos entre e dentro dos torneios de Thompson eq. 13.6
#' (`variancia_entre()`, `variancia_dentro()`). Com b = B o 1º termo some.
#'
#' @param resp data.frame dos respondentes, com `bloco_id`, `estrato`,
#'   `torneio_id` e `n_inscritos`.
#' @param a numeric, variavel por respondente (mesma ordem de `resp`).
#' @param N_jh numeric nomeado por celula (`"bloco|estrato"`).
#' @param B numeric, blocos na moldura.
#' @return lista com `total`, `variancia`, `b` e `blocos` (data.frame com
#'   `bloco_id`, `Y_j` e `v_j`).
total_tres_estagios <- function(resp, a, N_jh, B) {
  celula <- paste(resp$bloco_id, resp$estrato, sep = "|")
  torneio <- paste(celula, resp$torneio_id, sep = "|")
  primeiro <- !duplicated(torneio)
  tor <- data.frame(
    bloco_id = resp$bloco_id[primeiro],
    celula = celula[primeiro],
    M = resp$n_inscritos[primeiro],
    stringsAsFactors = FALSE
  )
  chave <- torneio[primeiro]
  tor$m <- as.numeric(tapply(a, torneio, length)[chave])
  tor$T <- tor$M * as.numeric(tapply(a, torneio, mean)[chave])
  tor$s2 <- as.numeric(tapply(a, torneio, stats::var)[chave])

  cel <- lapply(split(tor, tor$celula), function(d) {
    N <- N_jh[[d$celula[1]]]
    data.frame(
      bloco_id = d$bloco_id[1],
      Y = (N / nrow(d)) * sum(d$T),
      v = variancia_entre(N, d$T) + variancia_dentro(N, d$M, d$m, d$s2)
    )
  })
  cel <- do.call(rbind, cel)
  blocos <- data.frame(
    bloco_id = sort(unique(cel$bloco_id)),
    Y_j = as.numeric(tapply(cel$Y, cel$bloco_id, sum)),
    v_j = as.numeric(tapply(cel$v, cel$bloco_id, sum))
  )

  b <- nrow(blocos)
  entre_blocos <- if (b == B) 0 else B^2 * (1 - b / B) * stats::var(blocos$Y_j) / b
  list(
    total = (B / b) * sum(blocos$Y_j),
    variancia = entre_blocos + (B / b) * sum(blocos$v_j),
    b = b,
    blocos = blocos
  )
}

#' Estima a media (ROI ou proporcao de lucrativos) no plano de tres estagios.
#'
#' Estimador razao, porque M0 da populacao (todos os B blocos) e desconhecido
#' (ADR-002; Metodologia §7.5): R = Ŷ(y/f) / Ŷ(1/f), com f = 1 por inscricao
#' ou f_i = `frequencia_no_periodo()` por jogador distinto (ADR-009).
#' Variancia por linearizacao, z_i = (y_i - R)/f_i: Var(R) = Var(Ẑ)/Ŷ(1/f)^2
#' (Metodologia §8.2). IC t com gl = b - 1 (ADR-004).
#'
#' Exige b >= 2 blocos com respondentes, salvo b = B (censo dos blocos).
#'
#' @param coleta data.frame (ver `carregar_coleta()`), com `bloco_id` e, se
#'   `unidade = "jogador"`, `n_jogos_dia` dos respondentes.
#' @param moldura data.frame (ver `montar_moldura()`), torneios dos blocos listados.
#' @param B numeric, blocos na moldura temporal.
#' @param variavel character, `"roi"` ou `"lucrativo"`.
#' @param unidade character, `"jogador"` (ROI medio por jogador distinto) ou
#'   `"inscricao"` (por inscricao jogador x torneio).
#' @param nivel numeric, nivel de confianca do IC.
#' @return lista com `estimativa`, `variancia`, `erro_padrao`, `gl`, `li`,
#'   `ls`, `unidade`, `N_hat` (inscricoes ou jogadores estimados), `b`,
#'   `blocos` e `amostra` (`y`, peso final `w` e `torneio`, para o EPA).
estimar_media_tres_estagios <- function(coleta, moldura, B, variavel = "roi",
                                        unidade = c("jogador", "inscricao"),
                                        nivel = 0.95) {
  unidade <- match.arg(unidade)
  resp <- coleta[coleta$respondeu %in% TRUE, , drop = FALSE]
  celula <- paste(resp$bloco_id, resp$estrato, sep = "|")
  torneio <- paste(celula, resp$torneio_id, sep = "|")
  m_k <- as.numeric(table(torneio)[torneio])
  # Minimos por celula (n_jh >= 2) e por torneio (m_k >= 2).
  por_torneio <- data.frame(estrato = celula, torneio_id = resp$torneio_id, m = m_k)
  validar_tamanhos(por_torneio[!duplicated(torneio), ])

  N_jh <- table(paste(moldura$bloco_id, moldura$estrato, sep = "|"))
  f <- if (unidade == "jogador") {
    if (anyNA(resp$n_jogos_dia)) {
      stop("n_jogos_dia ausente em respondentes; necessario para unidade = 'jogador'.")
    }
    frequencia_no_periodo(resp$n_jogos_dia)
  } else {
    rep(1, nrow(resp))
  }
  y <- resp[[variavel]]

  num <- total_tres_estagios(resp, y / f, N_jh, B)
  den <- total_tres_estagios(resp, 1 / f, N_jh, B)
  if (num$b < 2 && num$b < B) stop("Sao necessarios ao menos 2 blocos com respondentes.")
  estimativa <- num$total / den$total
  lin <- total_tres_estagios(resp, (y - estimativa) / f, N_jh, B)
  variancia <- lin$variancia / den$total^2

  # Peso final w = (B/b)(N_jh/n_jh)(M_k/m_k)/f (Metodologia §7.4).
  n_cel <- tapply(resp$torneio_id, celula, function(x) length(unique(x)))
  w <- (B / num$b) * as.numeric(N_jh[celula] / n_cel[celula]) * resp$n_inscritos / m_k / f

  # gl = b - 1 (ADR-004). Com b = B os blocos viram estratos e vale
  # gl = sum(n_jh) - numero de celulas, como no plano em dois estagios.
  gl <- if (num$b < B) num$b - 1 else sum(n_cel) - length(n_cel)
  resultado <- montar_resultado(estimativa, variancia, gl = gl, nivel = nivel)
  c(resultado, list(
    unidade = unidade, N_hat = den$total, b = num$b, blocos = num$blocos,
    amostra = data.frame(y = y, w = w, torneio = torneio)
  ))
}

#' EPA e rho_int do plano de tres estagios (Metodologia §9; ADR-005).
#'
#' @param resultado lista de `estimar_media_tres_estagios()`.
#' @return lista como em `epa_ponderado()`.
calcular_epa_tres_estagios <- function(resultado) {
  a <- resultado$amostra
  epa_ponderado(resultado$variancia, a$y, a$w, a$torneio, resultado$N_hat)
}
