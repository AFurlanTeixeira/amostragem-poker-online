#' Analise exploratoria do top 10 dos torneios sorteados e comparacao com a
#' amostra aleatoria, a estimativa do plano e a populacao do Kaggle.
#'
#' O top 10 fica fora do plano amostral (ver `carregar_top10()`): e uma
#' selecao intencional dos 10 primeiros de cada torneio original, sem peso.
#' Tudo aqui e descritivo; os p-valores tratam jogadores como independentes.
#'
#' Grupos de comparacao, sempre nos mesmos torneios (os 24 originais, em que o
#' top 10 foi consultado):
#'   - `"top 10"`: posicoes 1 a 10;
#'   - `"amostra, posicao > 10"`: a amostra aleatoria fora do top 10, para os
#'     grupos nao se sobreporem (posicoes 1 a 10 sorteadas na amostra sao o
#'     mesmo registro do top 10; ver `conferir_reconsultas()`).

POSICOES_TOP <- 10
# Nickname que o SharkScope mostra para perfis anonimos ("Anonimo", com
# acento); regex tolerante a codificacao.
PADRAO_ANONIMO <- "^An.{1,2}nimo$"
GRUPO_TOP10 <- "top 10"
GRUPO_AMOSTRA_FORA <- "amostra, posicao > 10"

#' Nickname sem o sufixo de re-entrada `[n]` que o top 10 guarda como a fonte
#' mostra (ex.: `comistus[2]`; ver `data/raw/README.md`).
#'
#' @param nickname character.
#' @return character.
nome_sem_sufixo <- function(nickname) {
  sub("\\[[0-9]+\\]$", "", nickname)
}

#' Prepara o top 10: so linhas consultadas, com estrato, M_k e indicadores.
#'
#' @param top10 data.frame de `carregar_top10()` (com `respondeu`, `roi`,
#'   `lucro` e `n_jogos_dia`).
#' @param moldura data.frame de `montar_moldura()`.
#' @return data.frame com as colunas do top 10 mais `estrato`, `n_inscritos`,
#'   `anonimo`, `lucrativo` (ROI > 0) e `lucrativo_estrito` (ROI > 0 e
#'   lucro > 0), como em `carregar_coleta()`. `nickname` fica sem o sufixo
#'   `[n]`, para comparar com a coleta e contar jogadores distintos.
preparar_top10 <- function(top10, moldura) {
  validar_colunas(top10, c("respondeu", "roi", "lucro"), "top 10 consultado")
  top10 <- top10[!is.na(top10$respondeu), , drop = FALSE]
  i <- match(top10$torneio_id, moldura$torneio_id)
  if (anyNA(i)) stop("Torneio do top 10 ausente na moldura.")
  top10$estrato <- moldura$estrato[i]
  top10$n_inscritos <- moldura$n_inscritos[i]
  top10$nickname <- nome_sem_sufixo(top10$nickname)
  top10$anonimo <- grepl(PADRAO_ANONIMO, top10$nickname)
  top10$lucrativo <- as.integer(top10$roi > 0)
  top10$lucrativo_estrito <- as.integer(top10$roi > 0 & top10$lucro > 0)
  top10
}

#' Resposta e ROI do top 10 por estrato ou por posicao.
#'
#' @param top10p data.frame de `preparar_top10()`.
#' @param por character, `"estrato"` ou `"posicao"`.
#' @return data.frame com a chave, `consultados`, `respondentes`,
#'   `anonimos`, `taxa_resposta`, `roi_mediana` e `prop_lucrativos`, e uma
#'   linha `"total"`.
resumir_resposta_top10 <- function(top10p, por = c("estrato", "posicao")) {
  por <- match.arg(por)
  chave <- if (por == "estrato") fator_estrato(top10p$estrato) else factor(top10p$posicao)
  grupos <- c(split(top10p, chave, drop = TRUE), total = list(top10p))
  res <- do.call(rbind, lapply(names(grupos), function(g) {
    d <- grupos[[g]]
    roi <- d$roi[d$respondeu]
    data.frame(
      chave = g, consultados = nrow(d), respondentes = length(roi),
      anonimos = sum(d$anonimo), taxa_resposta = mean(d$respondeu),
      roi_mediana = if (length(roi)) stats::median(roi) else NA_real_,
      prop_lucrativos = if (length(roi)) mean(roi > 0) else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  names(res)[1] <- por
  res
}

#' Posicoes 1 a 10 sorteadas na amostra aleatoria: o mesmo registro consultado
#' duas vezes (na coleta e no top 10).
#'
#' Serve de checagem de consistencia: o status de resposta deve coincidir e o
#' ROI so pode mudar pelo intervalo entre as consultas.
#'
#' @param top10p data.frame de `preparar_top10()`.
#' @param coleta data.frame de `carregar_coleta()`.
#' @return data.frame com `torneio_id`, `posicao`, `mesmo_nickname`,
#'   `respondeu_amostra`, `respondeu_top10`, `roi_amostra`, `roi_top10`,
#'   `dif_roi` (top 10 - amostra), `data_amostra` e `data_top10`.
conferir_reconsultas <- function(top10p, coleta) {
  amostra <- coleta[coleta$posicao <= POSICOES_TOP & !is.na(coleta$respondeu), , drop = FALSE]
  m <- merge(
    amostra[, c("torneio_id", "posicao", "nickname", "respondeu", "roi", "data_consulta")],
    top10p[, c("torneio_id", "posicao", "nickname", "respondeu", "roi", "data_consulta")],
    by = c("torneio_id", "posicao"), suffixes = c("_amostra", "_top10")
  )
  data.frame(
    torneio_id = m$torneio_id, posicao = m$posicao,
    mesmo_nickname = m$nickname_amostra == m$nickname_top10,
    respondeu_amostra = m$respondeu_amostra, respondeu_top10 = m$respondeu_top10,
    roi_amostra = m$roi_amostra, roi_top10 = m$roi_top10,
    dif_roi = m$roi_top10 - m$roi_amostra,
    data_amostra = m$data_consulta_amostra, data_top10 = m$data_consulta_top10,
    stringsAsFactors = FALSE
  )
}

#' Empilha top 10 e amostra aleatoria (posicao > 10) nos mesmos torneios.
#'
#' @param top10p data.frame de `preparar_top10()`.
#' @param coleta data.frame de `carregar_coleta()`.
#' @return data.frame com `grupo`, `bloco_id`, `estrato`, `torneio_id`,
#'   `posicao`, `nickname`, `respondeu`, `roi`, `lucro`, `n_jogos_dia`,
#'   `lucrativo` e `lucrativo_estrito`. Inclui os nao respondentes.
montar_grupos_top10 <- function(top10p, coleta) {
  colunas <- c(
    "bloco_id", "estrato", "torneio_id", "posicao", "nickname", "respondeu", "roi",
    "lucro", "n_jogos_dia", "lucrativo", "lucrativo_estrito"
  )
  fica <- coleta$torneio_id %in% top10p$torneio_id & coleta$posicao > POSICOES_TOP &
    !is.na(coleta$respondeu)
  fora <- coleta[fica, , drop = FALSE]
  rbind(
    data.frame(grupo = GRUPO_TOP10, top10p[, colunas], stringsAsFactors = FALSE),
    data.frame(grupo = GRUPO_AMOSTRA_FORA, fora[, colunas], stringsAsFactors = FALSE)
  )
}

#' Uma linha de resumo (sem peso) de um grupo de jogadores.
#'
#' @param d data.frame com `respondeu`, `roi`, `lucro`, `n_jogos_dia`,
#'   `lucrativo` e `lucrativo_estrito`.
#' @param grupo character, rotulo.
#' @return data.frame de uma linha.
linha_grupo <- function(d, grupo) {
  r <- d[d$respondeu %in% TRUE, , drop = FALSE]
  q <- stats::quantile(r$roi, c(0.25, 0.5, 0.75), names = FALSE)
  data.frame(
    grupo = grupo, consultados = nrow(d), respondentes = nrow(r),
    taxa_resposta = mean(d$respondeu), jogadores_distintos = length(unique(r$nickname)),
    roi_media = mean(r$roi), roi_aparada = mean(r$roi, trim = FRACAO_APARADA),
    roi_q1 = q[1], roi_mediana = q[2], roi_q3 = q[3],
    prop_lucrativos = mean(r$lucrativo), prop_lucrativos_estrito = mean(r$lucrativo_estrito),
    jogos_dia_mediana = stats::median(r$n_jogos_dia), lucro_mediana = stats::median(r$lucro),
    stringsAsFactors = FALSE
  )
}

#' Resumo sem peso por grupo (e, opcionalmente, por estrato dentro do grupo).
#'
#' @param grupos data.frame de `montar_grupos_top10()`.
#' @param por_estrato logical.
#' @return data.frame com `grupo`, `estrato` (se pedido) e as colunas de
#'   `linha_grupo()`.
resumir_grupos_top10 <- function(grupos, por_estrato = FALSE) {
  rotulos <- unique(grupos$grupo)
  if (!por_estrato) {
    return(do.call(rbind, lapply(rotulos, function(g) linha_grupo(grupos[grupos$grupo == g, ], g))))
  }
  do.call(rbind, lapply(ORDEM_ESTRATOS, function(h) {
    do.call(rbind, lapply(rotulos, function(g) {
      d <- grupos[grupos$grupo == g & grupos$estrato == h, , drop = FALSE]
      if (!any(d$respondeu)) return(NULL)
      cbind(estrato = h, linha_grupo(d, g), stringsAsFactors = FALSE)
    }))
  }))
}

#' Comparacao pareada por torneio: top 10 vs. amostra (posicao > 10).
#'
#' @param grupos data.frame de `montar_grupos_top10()`.
#' @return data.frame com `torneio_id`, `estrato`, taxas de resposta,
#'   respondentes, medianas do ROI de cada grupo e `dif_mediana`
#'   (top 10 - amostra; NA se algum grupo nao tem respondente).
comparar_por_torneio_top10 <- function(grupos) {
  torneios <- unique(grupos$torneio_id)
  do.call(rbind, lapply(torneios, function(k) {
    d <- grupos[grupos$torneio_id == k, , drop = FALSE]
    t10 <- d[d$grupo == GRUPO_TOP10, , drop = FALSE]
    amo <- d[d$grupo == GRUPO_AMOSTRA_FORA, , drop = FALSE]
    med <- function(x) if (any(x$respondeu)) stats::median(x$roi[x$respondeu]) else NA_real_
    data.frame(
      torneio_id = k, estrato = d$estrato[1],
      taxa_top10 = mean(t10$respondeu),
      taxa_amostra = if (nrow(amo)) mean(amo$respondeu) else NA_real_,
      resp_top10 = sum(t10$respondeu), resp_amostra = sum(amo$respondeu),
      mediana_top10 = med(t10), mediana_amostra = med(amo),
      dif_mediana = med(t10) - med(amo),
      stringsAsFactors = FALSE
    )
  }))
}

#' Testes descritivos: top 10 vs. amostra e ROI vs. posicao no top 10.
#'
#' Mann-Whitney (ROI) e Fisher (lucrativo) entre grupos; Wilcoxon pareado nas
#' diferencas de mediana por torneio (resposta e ROI); Spearman do ROI com a
#' posicao e com a posicao relativa (posicao / M_k) dentro do top 10. Ignoram
#' a conglomeracao em torneios e blocos.
#'
#' @param grupos data.frame de `montar_grupos_top10()`.
#' @param por_torneio data.frame de `comparar_por_torneio_top10()`.
#' @param top10p data.frame de `preparar_top10()`.
#' @return data.frame com `teste`, `estatistica`, `p_valor`, `n`.
testar_top10 <- function(grupos, por_torneio, top10p) {
  r <- grupos[grupos$respondeu %in% TRUE, , drop = FALSE]
  em_top <- r$grupo == GRUPO_TOP10
  mw <- suppressWarnings(stats::wilcox.test(r$roi[em_top], r$roi[!em_top]))
  fi <- stats::fisher.test(table(em_top, r$lucrativo))
  pares <- por_torneio[!is.na(por_torneio$dif_mediana), , drop = FALSE]
  wp <- suppressWarnings(stats::wilcox.test(pares$dif_mediana))
  tx <- por_torneio[!is.na(por_torneio$taxa_amostra), , drop = FALSE]
  wt <- suppressWarnings(stats::wilcox.test(tx$taxa_top10 - tx$taxa_amostra))
  rt <- top10p[top10p$respondeu, , drop = FALSE]
  sp <- suppressWarnings(stats::cor.test(rt$roi, rt$posicao, method = "spearman"))
  sr <- suppressWarnings(
    stats::cor.test(rt$roi, rt$posicao / rt$n_inscritos, method = "spearman")
  )
  data.frame(
    teste = c(
      "Mann-Whitney: ROI top 10 x amostra", "Fisher: lucrativo top 10 x amostra (OR)",
      "Wilcoxon pareado: dif. de mediana do ROI por torneio",
      "Wilcoxon pareado: dif. da taxa de resposta por torneio",
      "Spearman: ROI x posicao (top 10)", "Spearman: ROI x posicao / M_k (top 10)"
    ),
    estatistica = c(
      unname(mw$statistic), unname(fi$estimate), unname(wp$statistic), unname(wt$statistic),
      unname(sp$estimate), unname(sr$estimate)
    ),
    p_valor = c(mw$p.value, fi$p.value, wp$p.value, wt$p.value, sp$p.value, sr$p.value),
    n = c(nrow(r), nrow(r), nrow(pares), nrow(tx), nrow(rt), nrow(rt)),
    stringsAsFactors = FALSE
  )
}

#' Tabela de referencia: top 10 ao lado dos outros resultados do projeto.
#'
#' Linhas: populacao do Kaggle (se dada), estimativa do plano de tres estagios
#' (com peso, por jogador), amostra aleatoria (todos os respondentes, sem
#' peso), amostra fora do top 10 e top 10 (mesmos torneios, sem peso).
#'
#' @param grupos data.frame de `montar_grupos_top10()`.
#' @param coleta data.frame de `carregar_coleta()`.
#' @param moldura data.frame de `montar_moldura()`.
#' @param B numeric, blocos na moldura.
#' @param populacao_kaggle data.frame de `carregar_populacao_kaggle()` ou NULL.
#' @return data.frame com `fonte`, `tipo`, `n`, `roi_media`, `roi_mediana`,
#'   `prop_lucrativos`.
tabela_referencia_top10 <- function(grupos, coleta, moldura, B, populacao_kaggle = NULL) {
  linha <- function(fonte, tipo, n, roi, mediana, p) {
    data.frame(
      fonte = fonte, tipo = tipo, n = n, roi_media = roi, roi_mediana = mediana,
      prop_lucrativos = p, stringsAsFactors = FALSE
    )
  }
  resumo <- function(d, fonte) {
    r <- d[d$respondeu %in% TRUE, , drop = FALSE]
    linha(fonte, "sem peso", nrow(r), mean(r$roi), stats::median(r$roi), mean(r$roi > 0))
  }
  plano_roi <- estimar_media_tres_estagios(coleta, moldura, B, "roi", unidade = "jogador")
  plano_p <- estimar_media_tres_estagios(coleta, moldura, B, "lucrativo", unidade = "jogador")
  linhas <- list(
    if (!is.null(populacao_kaggle)) {
      linha(
        "Kaggle (populacao)", "parametro", nrow(populacao_kaggle), mean(populacao_kaggle$roi),
        stats::median(populacao_kaggle$roi), mean(populacao_kaggle$lucrativo)
      )
    },
    linha(
      "Campo: plano em tres estagios", "com peso (1/f_i)", sum(coleta$respondeu %in% TRUE),
      plano_roi$estimativa, NA_real_, plano_p$estimativa
    ),
    resumo(coleta, "Campo: amostra aleatoria (32 torneios)"),
    resumo(grupos[grupos$grupo == GRUPO_AMOSTRA_FORA, ], "Campo: amostra, posicao > 10 (24)"),
    resumo(grupos[grupos$grupo == GRUPO_TOP10, ], "Top 10 (24 torneios)")
  )
  do.call(rbind, linhas)
}

# ---------------------------------------------------------------------------
# Graficos (base R). Desenham no dispositivo aberto; quem chama abre e fecha.
# ---------------------------------------------------------------------------

#' Top 10 por posicao: taxa de resposta e ROI dos respondentes.
#'
#' Uma serie so (sem legenda); a cor dos pontos de ROI segue o estrato.
#'
#' @param top10p data.frame de `preparar_top10()`.
#' @param teto numeric, limite superior do eixo do ROI.
#' @return NULL, invisivelmente.
grafico_top10_posicao <- function(top10p, teto = 100) {
  antigo <- graphics::par(mfrow = c(1, 2), mar = c(4, 4.5, 3, 1), family = "sans")
  on.exit(graphics::par(antigo))
  pos <- seq_len(POSICOES_TOP)
  eixo_posicao <- function() {
    graphics::axis(1, at = pos, tick = FALSE, col.axis = "grey20")
    graphics::mtext("posição no torneio", side = 1, line = 2.5, col = "grey30", cex = 0.85)
  }
  taxa <- tapply(top10p$respondeu, factor(top10p$posicao, levels = pos), mean)
  graphics::plot(NA, xlim = c(0.5, POSICOES_TOP + 0.5), ylim = c(0, 1), axes = FALSE,
    xlab = "", ylab = ""
  )
  graphics::title(main = "Taxa de resposta por posição", adj = 0, font.main = 1,
    cex.main = 1, col.main = "grey10"
  )
  marcas <- seq(0, 1, 0.2)
  graphics::abline(h = marcas, col = "grey90")
  graphics::axis(2, at = marcas, labels = sprintf("%.0f%%", 100 * marcas), las = 1, tick = FALSE,
    col.axis = "grey30"
  )
  eixo_posicao()
  graphics::lines(pos, taxa, col = "grey40", lwd = 2)
  graphics::points(pos, taxa, pch = 21, bg = "grey20", col = "white", cex = 1.4)

  r <- top10p[top10p$respondeu, , drop = FALSE]
  fora <- r$roi > teto
  ylim <- c(min(r$roi, 0), teto)
  graphics::plot(NA, xlim = c(0.5, POSICOES_TOP + 0.5), ylim = ylim, axes = FALSE,
    xlab = "", ylab = ""
  )
  graphics::title(main = "ROI dos respondentes (%), mediana em traço", adj = 0, font.main = 1,
    cex.main = 1, col.main = "grey10"
  )
  marcas <- graphics::axTicks(2)
  graphics::abline(h = marcas, col = "grey90")
  graphics::abline(h = 0, col = "grey40")
  graphics::axis(2, at = marcas, las = 1, tick = FALSE, col.axis = "grey30")
  eixo_posicao()
  dx <- stats::ave(r$roi, r$posicao, FUN = function(y) espalhar_pontos(y, 0.12))
  graphics::points((r$posicao + dx)[!fora], r$roi[!fora],
    pch = 21, bg = CORES_ESTRATOS[r$estrato[!fora]], col = "white", cex = 1.1
  )
  if (any(fora)) {
    graphics::points(r$posicao[fora], rep(teto, sum(fora)), pch = 24, bg = "grey15",
      col = "white", cex = 1.3
    )
    graphics::text(r$posicao[fora], teto, sprintf("%s%%", format(r$roi[fora], decimal.mark = ",")),
      pos = 1, cex = 0.75, col = "grey20"
    )
  }
  med <- tapply(r$roi, factor(r$posicao, levels = pos), stats::median)
  graphics::segments(pos - 0.3, med, pos + 0.3, med, lwd = 2, col = "grey15")
  graphics::legend("bottomright",
    legend = NOMES_ESTRATOS[ORDEM_ESTRATOS], pch = 21,
    pt.bg = CORES_ESTRATOS[ORDEM_ESTRATOS], col = "white", pt.cex = 1.2, bty = "n", cex = 0.8
  )
  invisible(NULL)
}

#' ROI por estrato: amostra (posicao > 10, ponto cheio) x top 10 (vazado).
#'
#' @param grupos data.frame de `montar_grupos_top10()`.
#' @param teto numeric, limite superior do eixo do ROI.
#' @param referencia numeric ou NULL, linha tracejada (ex.: estimativa do
#'   plano).
#' @return NULL, invisivelmente.
grafico_top10_vs_amostra <- function(grupos, teto = 100, referencia = NULL) {
  antigo <- graphics::par(mar = c(3, 4.5, 3, 1), family = "sans")
  on.exit(graphics::par(antigo))
  r <- grupos[grupos$respondeu %in% TRUE, , drop = FALSE]
  graphics::plot(NA,
    xlim = c(0.5, length(ORDEM_ESTRATOS) + 0.5), ylim = c(min(r$roi, 0), teto),
    axes = FALSE, xlab = "", ylab = ""
  )
  graphics::title(main = "ROI (%): amostra aleatória (posição > 10) x top 10",
    adj = 0, font.main = 1, cex.main = 1, col.main = "grey10"
  )
  desenhar_eixos(NOMES_ESTRATOS[ORDEM_ESTRATOS])
  graphics::abline(h = 0, col = "grey40")
  if (!is.null(referencia)) graphics::abline(h = referencia, lty = 2, col = "grey30")
  estilos <- list(list(GRUPO_AMOSTRA_FORA, -0.2, 21), list(GRUPO_TOP10, 0.2, 1))
  for (e in estilos) {
    d <- r[r$grupo == e[[1]], , drop = FALSE]
    x <- as.integer(fator_estrato(d$estrato)) + e[[2]]
    dx <- stats::ave(d$roi, d$estrato, FUN = function(y) espalhar_pontos(y, 0.1))
    fora <- d$roi > teto
    cor <- CORES_ESTRATOS[d$estrato]
    graphics::points((x + dx)[!fora], d$roi[!fora],
      pch = e[[3]], col = if (e[[3]] == 21) "white" else cor[!fora],
      bg = cor[!fora], cex = 1.1, lwd = 1.5
    )
    if (any(fora)) {
      graphics::points(x[fora], rep(teto, sum(fora)), pch = 24, bg = "grey15", col = "white")
      graphics::text(x[fora], teto, sprintf("%s%%", format(d$roi[fora], decimal.mark = ",")),
        pos = 4, cex = 0.75, col = "grey20"
      )
    }
    med <- tapply(d$roi, fator_estrato(d$estrato), stats::median)
    xs <- seq_along(ORDEM_ESTRATOS) + e[[2]]
    graphics::segments(xs - 0.15, med, xs + 0.15, med, lwd = 2, col = "grey15")
  }
  legenda <- c("amostra (posição > 10)", "top 10")
  lty <- c(NA, NA)
  pch <- c(19, 1)
  if (!is.null(referencia)) {
    legenda <- c(legenda, "estimativa do plano")
    lty <- c(lty, 2)
    pch <- c(pch, NA)
  }
  graphics::legend("bottomleft",
    legend = legenda, pch = pch, lty = lty, col = "grey30",
    pt.cex = 1.2, pt.lwd = 1.5, bty = "n", cex = 0.8
  )
  invisible(NULL)
}
