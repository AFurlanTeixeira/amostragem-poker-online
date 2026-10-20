#' Estimadores da amostragem estratificada em dois estagios (coleta de campo).
#'
#' Notacao do plano (docs/plano_projeto.md, §4): estrato h, torneio k,
#' jogador i; N_h/n_h torneios (populacao/amostra); M_hk/m_hk jogadores.
#'
#' Referencias: Thompson (2012), §13.1 (eq. 13.1-13.8 e estimador razao) e
#' §11.1-11.2 (soma das variancias entre estratos); Bolfarine & Bussab,
#' cap. 8 (eq. 8.13, Prop. 8.1, eq. 8.24-8.26) e §3.4 (EPA).

#' Resume a amostra de cada torneio sorteado.
#'
#' Usa apenas os jogadores que responderam (perfil publico). Sob a hipotese
#' de nao resposta aleatoria dentro do torneio, `m` = numero de respondentes
#' (plano §5.1).
#'
#' @param coleta data.frame (ver `carregar_coleta()`).
#' @param variavel character, coluna analisada (`"roi"` ou `"lucrativo"`).
#' @return data.frame com uma linha por torneio: `estrato`, `torneio_id`,
#'   `M` (inscritos), `m` (respondentes), `ybar`, `s2` e `yhat = M * ybar`
#'   (Thompson eq. 13.1).
resumir_torneios <- function(coleta, variavel = "roi") {
  resp <- coleta[coleta$respondeu %in% TRUE, , drop = FALSE]
  chave <- paste(resp$estrato, resp$torneio_id, sep = "\r")
  y <- resp[[variavel]]
  primeiro <- !duplicated(chave)

  resumo <- data.frame(
    estrato = resp$estrato[primeiro],
    torneio_id = resp$torneio_id[primeiro],
    M = resp$n_inscritos[primeiro],
    stringsAsFactors = FALSE
  )
  chave_unica <- chave[primeiro]
  resumo$m <- as.numeric(tapply(y, chave, length)[chave_unica])
  resumo$ybar <- as.numeric(tapply(y, chave, mean)[chave_unica])
  resumo$s2 <- as.numeric(tapply(y, chave, stats::var)[chave_unica])
  resumo$yhat <- resumo$M * resumo$ybar
  resumo
}

#' Termo de variancia DENTRO dos torneios de um estrato (escala do total).
#'
#' (N_h / n_h) * sum_k M_k^2 (1 - m_k/M_k) s_k^2 / m_k  (Thompson eq. 13.6,
#' 2a parcela).
#'
#' @param N_h numeric, torneios do estrato na populacao.
#' @param M,m,s2 numeric, por torneio sorteado.
#' @return numeric.
variancia_dentro <- function(N_h, M, m, s2) {
  (N_h / length(M)) * sum(M^2 * (1 - m / M) * s2 / m)
}

#' Termo de variancia ENTRE torneios de um estrato (escala do total).
#'
#' N_h^2 (1 - n_h/N_h) s_u^2 / n_h, com s_u^2 = variancia amostral de `z`
#' (Thompson eq. 13.6-13.7). `z` sao os totais estimados `yhat` (estimador
#' nao viesado) ou os residuos `yhat - r M` (estimador razao).
#'
#' @param N_h numeric, torneios do estrato na populacao.
#' @param z numeric, um valor por torneio sorteado.
#' @return numeric.
variancia_entre <- function(N_h, z) {
  n_h <- length(z)
  N_h^2 * (1 - n_h / N_h) * stats::var(z) / n_h
}

#' Estima a media por jogador sob amostragem estratificada em dois estagios.
#'
#' - `"nao_viesado"`: mu = sum(tau_h) / M0, exige M0 conhecido (plano §4.2a).
#' - `"razao"`: mu_R = sum(tau_h) / sum(Mhat_h) (plano §4.2b).
#' - `"auto"`: usa `"nao_viesado"` se a moldura tiver `n_inscritos` de todos
#'   os torneios; senao, `"razao"`.
#'
#' Para a proporcao de lucrativos, use `variavel = "lucrativo"`.
#'
#' @param coleta data.frame (ver `carregar_coleta()`).
#' @param moldura data.frame (ver `montar_moldura()`), populacao de torneios.
#' @param variavel character, coluna analisada.
#' @param metodo character, `"auto"`, `"nao_viesado"` ou `"razao"`.
#' @param nivel numeric, nivel de confianca do IC (t com gl = sum(n_h) - H).
#' @return lista com `estimativa`, `variancia`, `erro_padrao`, `gl`, `li`,
#'   `ls`, `metodo`, `M0` e `componentes` (data.frame por estrato).
estimar_media_dois_estagios <- function(coleta, moldura, variavel = "roi",
                                        metodo = c("auto", "nao_viesado", "razao"),
                                        nivel = 0.95) {
  metodo <- match.arg(metodo)
  resumo <- resumir_torneios(coleta, variavel)
  validar_tamanhos(resumo)

  N_h <- table(moldura$estrato)
  M0_conhecido <- !anyNA(moldura$n_inscritos)
  if (metodo == "auto") metodo <- if (M0_conhecido) "nao_viesado" else "razao"
  if (metodo == "nao_viesado" && !M0_conhecido) {
    stop("Estimador nao viesado exige n_inscritos de todos os torneios da moldura.")
  }

  estratos <- sort(unique(resumo$estrato))
  por_estrato <- split(resumo, factor(resumo$estrato, levels = estratos))
  componentes <- data.frame(
    estrato = estratos,
    N_h = as.numeric(N_h[estratos]),
    n_h = vapply(por_estrato, nrow, numeric(1)),
    tau_h = vapply(estratos, function(h) {
      (N_h[[h]] / nrow(por_estrato[[h]])) * sum(por_estrato[[h]]$yhat)
    }, numeric(1)),
    M_hat_h = vapply(estratos, function(h) {
      (N_h[[h]] / nrow(por_estrato[[h]])) * sum(por_estrato[[h]]$M)
    }, numeric(1)),
    dentro = vapply(estratos, function(h) {
      d <- por_estrato[[h]]
      variancia_dentro(N_h[[h]], d$M, d$m, d$s2)
    }, numeric(1)),
    row.names = NULL,
    stringsAsFactors = FALSE
  )

  if (metodo == "nao_viesado") {
    M0 <- sum(moldura$n_inscritos)
    estimativa <- sum(componentes$tau_h) / M0
    z_por_estrato <- lapply(por_estrato, function(d) d$yhat)
  } else {
    M0 <- if (M0_conhecido) sum(moldura$n_inscritos) else sum(componentes$M_hat_h)
    estimativa <- sum(componentes$tau_h) / sum(componentes$M_hat_h)
    z_por_estrato <- lapply(por_estrato, function(d) d$yhat - estimativa * d$M)
  }
  componentes$entre <- vapply(estratos, function(h) {
    variancia_entre(N_h[[h]], z_por_estrato[[h]])
  }, numeric(1))

  variancia <- sum(componentes$entre + componentes$dentro) / M0^2
  resultado <- montar_resultado(
    estimativa, variancia,
    gl = sum(componentes$n_h) - length(estratos), nivel = nivel
  )
  c(resultado, list(metodo = metodo, M0 = M0, componentes = componentes))
}

#' Efeito do Planejamento (EPA/DEFF) e correlacao intraclasse estimada.
#'
#' EPA = Var(mu_hat) / Var_AAS, com Var_AAS = (1 - n/M0) s_y^2 / n e s_y^2
#' estimada na propria amostra de campo com os pesos amostrais
#' w = (N_h/n_h)(M_hk/m_hk) (Bolfarine & Bussab §3.4). rho_int vem da
#' aproximacao EPA ~ 1 + rho_int (mbar - 1) (Bolfarine & Bussab eq. 8.26).
#'
#' @param resultado lista de `estimar_media_dois_estagios()`.
#' @param coleta data.frame (ver `carregar_coleta()`).
#' @param moldura data.frame (ver `montar_moldura()`).
#' @param variavel character, mesma coluna usada em `resultado`.
#' @return lista com `epa`, `var_aas`, `s2_y`, `n`, `m_medio`, `rho_int`.
calcular_epa <- function(resultado, coleta, moldura, variavel = "roi") {
  resp <- coleta[coleta$respondeu %in% TRUE, , drop = FALSE]
  N_h <- table(moldura$estrato)
  n_h <- tapply(resp$torneio_id, resp$estrato, function(x) length(unique(x)))
  chave <- paste(resp$estrato, resp$torneio_id, sep = "\r")
  m_k <- table(chave)[chave]

  w <- as.numeric(N_h[resp$estrato] / n_h[resp$estrato]) * resp$n_inscritos / as.numeric(m_k)
  y <- resp[[variavel]]
  n <- length(y)
  media_w <- sum(w * y) / sum(w)
  s2_y <- (n / (n - 1)) * sum(w * (y - media_w)^2) / sum(w)

  var_aas <- (1 - n / resultado$M0) * s2_y / n
  epa <- resultado$variancia / var_aas
  m_medio <- n / length(unique(chave))
  list(
    epa = epa,
    var_aas = var_aas,
    s2_y = s2_y,
    n = n,
    m_medio = m_medio,
    rho_int = (epa - 1) / (m_medio - 1)
  )
}

#' Taxa de nao resposta (perfis privados) por estrato.
#'
#' Linhas com `respondeu` ausente (reservas que nao chegaram a ser
#' consultadas) ficam de fora.
#'
#' @param coleta data.frame (ver `carregar_coleta()`).
#' @return data.frame com `estrato`, `consultados`, `privados`, `taxa_nao_resposta`.
taxa_nao_resposta <- function(coleta) {
  coleta <- coleta[!is.na(coleta$respondeu), , drop = FALSE]
  consultados <- tapply(coleta$respondeu, coleta$estrato, length)
  privados <- tapply(!coleta$respondeu, coleta$estrato, sum)
  data.frame(
    estrato = names(consultados),
    consultados = as.integer(consultados),
    privados = as.integer(privados),
    taxa_nao_resposta = as.numeric(privados / consultados),
    row.names = NULL
  )
}

#' Garante n_h >= 2 torneios por estrato e m >= 2 respondentes por torneio.
#'
#' @param resumo data.frame de `resumir_torneios()`.
#' @return `resumo`, invisivelmente; erro se os minimos nao forem atendidos.
validar_tamanhos <- function(resumo) {
  n_h <- table(resumo$estrato)
  if (any(n_h < N_MINIMO_POR_ESTRATO)) {
    stop("Estratos com menos de 2 torneios: ", paste(names(n_h)[n_h < 2], collapse = ", "))
  }
  if (any(resumo$m < M_MINIMO_POR_TORNEIO)) {
    poucos <- resumo$torneio_id[resumo$m < M_MINIMO_POR_TORNEIO]
    stop("Torneios com menos de 2 respondentes: ", paste(poucos, collapse = ", "))
  }
  invisible(resumo)
}
