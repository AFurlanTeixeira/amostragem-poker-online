#' Estimadores para amostragem direta de elementos: AAS e AAS estratificada.
#'
#' Referencias: Thompson (2012), cap. 2 e cap. 11 (eq. 11.1-11.4);
#' Bolfarine & Bussab, cap. 3 e 4.

#' Media, variancia estimada e IC sob AAS sem reposicao.
#'
#' Var(ybar) estimada = (1 - n/N) s^2 / n (com FCPF).
#'
#' @param y numeric, valores observados na amostra.
#' @param N integer, tamanho da populacao.
#' @param nivel numeric, nivel de confianca do IC.
#' @return lista com `estimativa`, `variancia`, `erro_padrao`, `gl`, `li`, `ls`.
estimar_media_aas <- function(y, N, nivel = 0.95) {
  n <- length(y)
  variancia <- (1 - n / N) * stats::var(y) / n
  montar_resultado(mean(y), variancia, gl = n - 1, nivel = nivel)
}

#' Combina estatisticas por estrato no estimador estratificado da media.
#'
#' ybar_st = sum(W_h ybar_h), com W_h = N_h / N (Thompson eq. 11.1);
#' var = sum(W_h^2 (1 - n_h/N_h) s_h^2 / n_h) (Thompson eq. 11.3);
#' gl de Satterthwaite (Thompson eq. 11.4).
#'
#' @param N_h,n_h numeric, tamanhos populacional e amostral por estrato.
#' @param ybar_h,s2_h numeric, media e variancia amostral por estrato.
#' @param nivel numeric, nivel de confianca do IC.
#' @return lista como em `estimar_media_aas()`.
combinar_estratos <- function(N_h, n_h, ybar_h, s2_h, nivel = 0.95) {
  w_h <- N_h / sum(N_h)
  estimativa <- sum(w_h * ybar_h)
  variancia <- sum(w_h^2 * (1 - n_h / N_h) * s2_h / n_h)
  a_h <- N_h * (N_h - n_h) / n_h
  gl <- gl_satterthwaite(a_h * s2_h, n_h - 1)
  montar_resultado(estimativa, variancia, gl = gl, nivel = nivel)
}

#' AAS estratificada a partir dos dados da amostra.
#'
#' @param y numeric, valores observados.
#' @param estrato character, estrato de cada observacao (mesmo tamanho de `y`).
#' @param N_h numeric nomeado por estrato, tamanhos populacionais.
#' @param nivel numeric, nivel de confianca do IC.
#' @return lista como em `estimar_media_aas()`.
estimar_media_estratificada <- function(y, estrato, N_h, nivel = 0.95) {
  estratos <- names(N_h)
  n_h <- as.numeric(table(factor(estrato, levels = estratos)))
  ybar_h <- as.numeric(tapply(y, factor(estrato, levels = estratos), mean))
  s2_h <- as.numeric(tapply(y, factor(estrato, levels = estratos), stats::var))
  combinar_estratos(as.numeric(N_h), n_h, ybar_h, s2_h, nivel = nivel)
}

#' Graus de liberdade aproximados de Satterthwaite (Thompson eq. 11.4).
#'
#' @param termos numeric, parcelas `a_h s_h^2` da variancia.
#' @param gl_termos numeric, graus de liberdade de cada parcela (`n_h - 1`).
#' @return numeric.
gl_satterthwaite <- function(termos, gl_termos) {
  sum(termos)^2 / sum(termos^2 / gl_termos)
}

#' Monta a lista padrao de resultado com IC t.
#'
#' @param estimativa,variancia numeric.
#' @param gl numeric, graus de liberdade da t.
#' @param nivel numeric, nivel de confianca.
#' @return lista com `estimativa`, `variancia`, `erro_padrao`, `gl`, `li`, `ls`.
montar_resultado <- function(estimativa, variancia, gl, nivel) {
  erro_padrao <- sqrt(variancia)
  t_crit <- stats::qt(1 - (1 - nivel) / 2, df = gl)
  list(
    estimativa = estimativa,
    variancia = variancia,
    erro_padrao = erro_padrao,
    gl = gl,
    li = estimativa - t_crit * erro_padrao,
    ls = estimativa + t_crit * erro_padrao
  )
}
