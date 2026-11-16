# Graficos do relatorio final: intervalos de campo (§6.1), cobertura do plano
# na populacao sintetica (§5.3) e nao resposta por estrato (§6.5).
#
# Mesmo estilo de R base dos graficos da AED (exploracao_estratos.R). A cor dos
# estratos continua sendo CORES_ESTRATOS (slots 1-3); os metodos de variancia
# usam os slots 4, 5 e 7 da paleta categorica, para nao se confundir com os
# estratos. Os tres passam no validador de daltonismo, mas tem contraste < 3:1
# com o fundo, por isso toda serie e rotulada diretamente.

CORES_METODOS <- c(wald = "#eda100", logit = "#e87ba4", jk1 = "#6250d6")
PCH_METODOS <- c(wald = 15, logit = 17, jk1 = 19)
NOMES_METODOS <- c(wald = "Wald (EP linearizado)", logit = "logit (EP linearizado)", jk1 = "JK1")

#' Titulo de painel, no estilo da AED.
#'
#' @param texto character.
#' @return NULL, invisivelmente.
titulo_painel <- function(texto) {
  graphics::title(main = texto, adj = 0, font.main = 1, cex.main = 1, col.main = "grey10")
  invisible(NULL)
}

#' Um painel de intervalos: EP linearizado e JK1 lado a lado por parametro.
#'
#' @param d data.frame com `parametro`, `estimativa`, `li`, `ls`, `li_jk1`, `ls_jk1`.
#' @param titulo character.
#' @param referencia numeric, valor da linha de referencia.
#' @param rotulo_ref character, rotulo da linha de referencia.
#' @param ylim numeric(2).
#' @param legenda numeric(2) com a posicao (x, y) da legenda, ou NULL para nao desenhar.
#' @return NULL, invisivelmente.
painel_intervalos <- function(d, titulo, referencia, rotulo_ref, ylim, legenda = NULL) {
  graphics::plot(NA,
    xlim = c(0.4, nrow(d) + 0.6), ylim = ylim, axes = FALSE, xlab = "", ylab = ""
  )
  titulo_painel(titulo)
  desenhar_eixos(d$parametro)
  graphics::abline(h = referencia, col = "grey40", lty = 2)
  graphics::text(0.4, referencia, rotulo_ref, adj = c(0, -0.5), cex = 0.75, col = "grey30")
  series <- list(
    wald = list(dx = -0.12, li = d$li, ls = d$ls),
    jk1 = list(dx = 0.12, li = d$li_jk1, ls = d$ls_jk1)
  )
  for (m in names(series)) {
    x <- seq_len(nrow(d)) + series[[m]]$dx
    graphics::segments(x, series[[m]]$li, x, series[[m]]$ls, lwd = 3, col = CORES_METODOS[[m]])
    graphics::points(x, d$estimativa, pch = 21, bg = CORES_METODOS[[m]], col = "white", cex = 1.4)
  }
  graphics::text(seq_len(nrow(d)) + 0.2, d$estimativa,
    formatC(d$estimativa, format = "f", digits = if (max(abs(d$estimativa)) > 1) 1 else 2,
      decimal.mark = ","
    ),
    pos = 4, cex = 0.8, col = "grey10"
  )
  if (!is.null(legenda)) {
    graphics::legend(legenda[1], legenda[2],
      legend = c("EP linearizado", "EP JK1"), lwd = 3,
      col = CORES_METODOS[c("wald", "jk1")], bty = "n", cex = 0.8
    )
  }
  invisible(NULL)
}

#' Estimativas de campo com os dois IC de 95% (linearizado e JK1), §6.1.
#'
#' Dois paineis, porque ROI (%) e proporcoes tem escalas diferentes (nunca dois
#' eixos y no mesmo grafico). Nas proporcoes os dois IC sao logit (§4.6).
#'
#' @param estimativas data.frame com `parametro`, `escala` ("roi" ou "proporcao"),
#'   `estimativa`, `li`, `ls`, `li_jk1`, `ls_jk1`.
#' @return NULL, invisivelmente.
grafico_estimativas_ic <- function(estimativas) {
  colunas <- c("parametro", "escala", "estimativa", "li", "ls", "li_jk1", "ls_jk1")
  stopifnot(all(colunas %in% names(estimativas)))
  roi <- estimativas[estimativas$escala == "roi", , drop = FALSE]
  prop <- estimativas[estimativas$escala == "proporcao", , drop = FALSE]
  antigo <- graphics::par(mar = c(3, 4.5, 3, 1), family = "sans")
  on.exit(graphics::par(antigo))
  graphics::layout(matrix(1:2, nrow = 1), widths = c(1, 1.8))
  on.exit(graphics::layout(1), add = TRUE)
  faixa_roi <- range(c(0, roi$li, roi$ls, roi$li_jk1, roi$ls_jk1))
  painel_intervalos(roi, "Escala de ROI (%)", 0, "zero", faixa_roi + c(-3, 3))
  # Legenda no vao entre os dois parametros de proporcao, abaixo de "metade".
  painel_intervalos(prop, "Escala de proporção", 0.5, "metade", c(0, 1), legenda = c(1.22, 0.3))
  invisible(NULL)
}

#' Cobertura do IC de 95% do plano em tres estagios em funcao de b, §5.3.
#'
#' Um painel por parametro, com o mesmo eixo y; o logit so existe nas
#' proporcoes. Cada linha tem forma de marcador propria e rotulo direto.
#'
#' @param mc data.frame com `variavel`, `rotulo`, `b`, `cobertura_wald`,
#'   `cobertura_logit` (NA no ROI) e `cobertura_jk1`, em proporcao.
#' @param nivel numeric, nivel nominal (linha de referencia).
#' @return NULL, invisivelmente.
grafico_cobertura_b <- function(mc, nivel = 0.95) {
  stopifnot(all(c("variavel", "rotulo", "b", "cobertura_wald", "cobertura_jk1") %in% names(mc)))
  colunas <- c(wald = "cobertura_wald", logit = "cobertura_logit", jk1 = "cobertura_jk1")
  todos <- unlist(mc[intersect(colunas, names(mc))])
  ylim <- c(floor(100 * min(todos, na.rm = TRUE)) / 100 - 0.01, nivel + 0.01)
  b <- sort(unique(mc$b))
  antigo <- graphics::par(mfrow = c(1, length(unique(mc$variavel))), mar = c(4, 4.5, 3, 1),
    family = "sans"
  )
  on.exit(graphics::par(antigo))
  presentes <- names(colunas)[colunas %in% names(mc)]
  for (v in unique(mc$variavel)) {
    d <- mc[mc$variavel == v, , drop = FALSE]
    d <- d[order(d$b), , drop = FALSE]
    graphics::plot(NA,
      xlim = c(min(b) - 0.5, max(b) + 5), ylim = ylim, axes = FALSE, xlab = "", ylab = ""
    )
    titulo_painel(d$rotulo[1])
    marcas <- pretty(ylim)
    graphics::abline(h = marcas, col = "grey90")
    graphics::axis(2, at = marcas, labels = paste0(format(100 * marcas, decimal.mark = ","), "%"),
      las = 1, tick = FALSE, col.axis = "grey30"
    )
    graphics::axis(1, at = b, tick = FALSE, col.axis = "grey20")
    graphics::mtext("blocos sorteados (b)", side = 1, line = 2.5, cex = 0.75, col = "grey30")
    graphics::abline(h = nivel, col = "grey40", lty = 2)
    graphics::text(min(b) - 0.5, nivel, "95% nominal", adj = c(0, -0.5), cex = 0.75, col = "grey30")
    for (m in names(colunas)) {
      y <- d[[colunas[[m]]]]
      if (is.null(y) || all(is.na(y))) next
      graphics::lines(d$b, y, lwd = 2, col = CORES_METODOS[[m]])
      graphics::points(d$b, y, pch = PCH_METODOS[[m]], col = CORES_METODOS[[m]], cex = 1.3)
      graphics::text(max(b), y[length(y)], sub(" \\(.*", "", NOMES_METODOS[[m]]),
        pos = 4, cex = 0.8, col = "grey10"
      )
    }
    # Legenda so no 1o painel, na faixa de baixo, que fica vazia no ROI.
    if (v == unique(mc$variavel)[1]) {
      graphics::legend("bottomleft",
        legend = NOMES_METODOS[presentes], col = CORES_METODOS[presentes],
        pch = PCH_METODOS[presentes], lwd = 2, bty = "n", cex = 0.75
      )
    }
  }
  invisible(NULL)
}

#' Taxa de nao resposta por estrato, em barras horizontais, §6.5.
#'
#' @param nr data.frame com `estrato` e `taxa_nao_resposta` (proporcao).
#' @param total numeric, taxa geral (linha de referencia).
#' @return NULL, invisivelmente.
grafico_nao_resposta_estratos <- function(nr, total) {
  stopifnot(all(c("estrato", "taxa_nao_resposta") %in% names(nr)))
  nr <- nr[order(fator_estrato(nr$estrato)), , drop = FALSE]
  antigo <- graphics::par(mar = c(3, 6, 3, 2), family = "sans")
  on.exit(graphics::par(antigo))
  y <- rev(seq_len(nrow(nr)))
  graphics::plot(NA, xlim = c(0, 1), ylim = c(0.4, nrow(nr) + 0.6), axes = FALSE,
    xlab = "", ylab = ""
  )
  titulo_painel("Taxa de não resposta (perfis privados e \"Anônimo\")")
  marcas <- seq(0, 1, by = 0.25)
  graphics::abline(v = marcas, col = "grey90")
  graphics::axis(1, at = marcas, labels = paste0(100 * marcas, "%"), tick = FALSE,
    col.axis = "grey30"
  )
  graphics::axis(2, at = y, labels = NOMES_ESTRATOS[nr$estrato], las = 1, tick = FALSE,
    col.axis = "grey20"
  )
  graphics::rect(0, y - 0.32, nr$taxa_nao_resposta, y + 0.32,
    col = CORES_ESTRATOS[nr$estrato], border = "white", lwd = 2
  )
  graphics::text(nr$taxa_nao_resposta, y,
    paste0(formatC(100 * nr$taxa_nao_resposta, format = "f", digits = 0), "%"),
    pos = 4, cex = 0.85, col = "grey10"
  )
  graphics::abline(v = total, col = "grey15", lty = 2, lwd = 1.5)
  graphics::text(total, nrow(nr) + 0.5,
    sprintf("total: %s%%", formatC(100 * total, format = "f", digits = 0)),
    pos = 4, cex = 0.8, col = "grey15"
  )
  invisible(NULL)
}
