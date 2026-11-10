#' Analise exploratoria dos estratos de buy-in na coleta de campo (SharkScope).
#'
#' Fecha a ressalva de `docs/notas/estratificacao_buyin.md`: a escolha dos
#' estratos veio do Kaggle (buy-in medio do jogador); aqui se olha a moldura e
#' a amostra de campo (buy-in do torneio). Tabelas descritivas, estimativas por
#' dominio (estrato) com o estimador de tres estagios, decomposicao da soma de
#' quadrados por nivel do plano e comparacao com o top 10.
#'
#' As medidas sem peso (medias, DP, testes) descrevem os respondentes e ignoram
#' o plano: servem para explorar, nao para inferir. A inferencia por estrato
#' usa `estimar_dominios_estratos()`.

ORDEM_ESTRATOS <- ROTULOS_BUYIN
NOMES_ESTRATOS <- c(micro = "Micro", low = "Low", mid_high = "Mid/High")
# Slots 1-3 da paleta categorica (validados quanto a daltonismo); a cor segue
# o estrato em todos os graficos.
CORES_ESTRATOS <- c(micro = "#2a78d6", low = "#eb6834", mid_high = "#1baf7a")
FRACAO_APARADA <- 0.10

#' Fator com os estratos na ordem do plano (micro, low, mid_high).
#'
#' @param estrato character.
#' @return factor.
fator_estrato <- function(estrato) {
  factor(estrato, levels = ORDEM_ESTRATOS)
}

#' Resumo da moldura de torneios por estrato (Fase 1, Metodologia §6).
#'
#' @param moldura data.frame de `montar_moldura()`.
#' @return data.frame com `estrato`, `torneios` (N_h), `blocos`, faixa e
#'   mediana do buy-in, `inscricoes` (soma de M_k), mediana de M_k e as
#'   participacoes (%) em torneios e em inscricoes.
resumir_moldura_estratos <- function(moldura) {
  partes <- split(moldura, fator_estrato(moldura$estrato), drop = TRUE)
  res <- do.call(rbind, lapply(names(partes), function(h) {
    d <- partes[[h]]
    data.frame(
      estrato = h,
      torneios = nrow(d),
      blocos = length(unique(d$bloco_id)),
      buyin_min = min(d$buy_in),
      buyin_mediana = stats::median(d$buy_in),
      buyin_max = max(d$buy_in),
      inscricoes = sum(d$n_inscritos),
      inscritos_mediana = stats::median(d$n_inscritos),
      stringsAsFactors = FALSE
    )
  }))
  res$pct_torneios <- 100 * res$torneios / sum(res$torneios)
  res$pct_inscricoes <- 100 * res$inscricoes / sum(res$inscricoes)
  res
}

#' Tamanhos por celula bloco x estrato: moldura (N_jh) e amostra (n_jh).
#'
#' @param moldura data.frame de `montar_moldura()`.
#' @param coleta data.frame de `carregar_coleta()`.
#' @return data.frame com `bloco_id`, `estrato`, `N_jh`, `n_jh` (torneios
#'   sorteados), `inscricoes` (soma de M_k na celula) e `respondentes`.
tabela_celulas <- function(moldura, coleta) {
  chave_mol <- paste(moldura$bloco_id, moldura$estrato, sep = "|")
  chave_col <- paste(coleta$bloco_id, coleta$estrato, sep = "|")
  celulas <- unique(chave_mol)
  partes <- do.call(rbind, strsplit(celulas, "|", fixed = TRUE))
  res <- data.frame(
    bloco_id = as.integer(partes[, 1]),
    estrato = partes[, 2],
    N_jh = as.integer(table(chave_mol)[celulas]),
    n_jh = vapply(celulas, function(cl) {
      length(unique(coleta$torneio_id[chave_col == cl]))
    }, integer(1)),
    inscricoes = as.numeric(tapply(moldura$n_inscritos, chave_mol, sum)[celulas]),
    respondentes = vapply(celulas, function(cl) {
      sum(coleta$respondeu[chave_col == cl] %in% TRUE)
    }, integer(1)),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
  res[order(res$bloco_id, fator_estrato(res$estrato)), , drop = FALSE]
}

#' Estatisticas descritivas (sem peso) de uma variavel, por estrato.
#'
#' So os respondentes. Inclui uma linha `"total"`.
#'
#' @param coleta data.frame de `carregar_coleta()`.
#' @param variavel character, coluna numerica (ex.: `"roi"`).
#' @return data.frame com `estrato`, `n`, `media`, `media_aparada` (10% em
#'   cada cauda), `dp`, `minimo`, `q1`, `mediana`, `q3`, `maximo`.
resumir_variavel_estratos <- function(coleta, variavel) {
  resp <- coleta[coleta$respondeu %in% TRUE & !is.na(coleta[[variavel]]), , drop = FALSE]
  grupos <- c(
    split(resp[[variavel]], fator_estrato(resp$estrato), drop = TRUE),
    total = list(resp[[variavel]])
  )
  do.call(rbind, lapply(names(grupos), function(h) {
    y <- grupos[[h]]
    q <- stats::quantile(y, c(0.25, 0.5, 0.75), names = FALSE)
    data.frame(
      estrato = h, n = length(y), media = mean(y),
      media_aparada = mean(y, trim = FRACAO_APARADA), dp = stats::sd(y),
      minimo = min(y), q1 = q[1], mediana = q[2], q3 = q[3], maximo = max(y),
      stringsAsFactors = FALSE
    )
  }))
}

#' Estimativas por dominio (estrato) com o plano de tres estagios.
#'
#' Cada estrato, restrito aos blocos sorteados, e ele mesmo uma amostra em tres
#' estagios: blocos (AAS de b entre B) -> torneios do estrato no bloco (AAS de
#' n_jh entre N_jh) -> jogadores. Logo o estimador razao de
#' `estimar_media_tres_estagios()` aplicado ao subconjunto do estrato e o
#' estimador de dominio (Lohr, 2022, §4.3; Cochran, 1977, §2.13), com
#' gl = b - 1. Exige o estrato presente em todos os blocos com respondentes;
#' do contrario o bloco sem o estrato teria Y_j = 0 e nao poderia ser omitido.
#'
#' @param coleta data.frame de `carregar_coleta()`.
#' @param moldura data.frame de `montar_moldura()`.
#' @param B numeric, blocos na moldura temporal.
#' @param variavel character, `"roi"`, `"lucrativo"` ou `"lucrativo_estrito"`.
#' @param unidade character, `"jogador"` ou `"inscricao"`.
#' @return data.frame com `estrato` (inclui `"total"`), `estimativa`,
#'   `erro_padrao`, `li`, `ls` (IC logit para `lucrativo*`, ADR-012), `gl`,
#'   `N_hat` e `pct_N_hat` (participacao do estrato no N estimado).
estimar_dominios_estratos <- function(coleta, moldura, B, variavel = "roi",
                                      unidade = "jogador") {
  proporcao <- variavel %in% c("lucrativo", "lucrativo_estrito")
  geral <- estimar_media_tres_estagios(coleta, moldura, B, variavel, unidade = unidade)
  resp <- coleta[coleta$respondeu %in% TRUE, , drop = FALSE]
  blocos <- sort(unique(resp$bloco_id))
  presentes <- intersect(ORDEM_ESTRATOS, unique(resp$estrato))
  linhas <- lapply(presentes, function(h) {
    if (!setequal(unique(resp$bloco_id[resp$estrato == h]), blocos)) {
      stop(sprintf("Estrato %s ausente em algum bloco com respondentes.", h))
    }
    res <- estimar_media_tres_estagios(
      coleta[coleta$estrato == h, , drop = FALSE],
      moldura[moldura$estrato == h, , drop = FALSE],
      B, variavel,
      unidade = unidade
    )
    linha_dominio(h, res, proporcao)
  })
  res <- rbind(do.call(rbind, linhas), linha_dominio("total", geral, proporcao))
  res$pct_N_hat <- 100 * res$N_hat / geral$N_hat
  res
}

#' Uma linha da tabela de dominios.
#'
#' Para proporcoes (estimativa em [0, 1] e variavel diferente de ROI), o IC e
#' o logit (ADR-012), que fica dentro de (0, 1); para o ROI, o IC t de Wald.
#'
#' @param estrato character.
#' @param res lista de `estimar_media_tres_estagios()`.
#' @param proporcao logical, se a variavel e uma proporcao.
#' @return data.frame de uma linha.
linha_dominio <- function(estrato, res, proporcao = FALSE) {
  ic <- if (proporcao) ic_logit(res) else c(li = res$li, ls = res$ls)
  data.frame(
    estrato = estrato, estimativa = res$estimativa, erro_padrao = res$erro_padrao,
    li = ic[["li"]], ls = ic[["ls"]], gl = res$gl, N_hat = res$N_hat,
    stringsAsFactors = FALSE
  )
}

#' Decomposicao hierarquica da soma de quadrados pelos niveis do plano.
#'
#' Niveis aninhados: estrato > celula (bloco x estrato) > torneio > jogador.
#' SQ_total = sum_l sum_g n_g (ybar_g - ybar_pai(g))^2 + SQ_dentro dos
#' torneios (ANOVA hierarquica). Sem peso, so respondentes: mede, de forma
#' descritiva, quanto da variabilidade e explicada pelo estrato (eta^2). Com
#' alocacao proporcional, o EPA da estratificacao fica perto de 1 - eta^2
#' (ver `docs/notas/estratificacao_buyin.md`, §2). Para comparar niveis com
#' numeros de gl diferentes, use o quadrado medio (QM = SQ/gl), nao a
#' proporcao: QM_torneios ~ QM_dentro indica rho_int perto de zero.
#'
#' @param coleta data.frame de `carregar_coleta()`.
#' @param variavel character, coluna numerica.
#' @return data.frame com `componente`, `sq`, `gl`, `qm` e `proporcao` (da SQ
#'   total; soma 1).
decompor_variancia_estratos <- function(coleta, variavel) {
  resp <- coleta[coleta$respondeu %in% TRUE & !is.na(coleta[[variavel]]), , drop = FALSE]
  y <- resp[[variavel]]
  niveis <- list(
    estrato = resp$estrato,
    celula = paste(resp$estrato, resp$bloco_id, sep = "|"),
    torneio = paste(resp$estrato, resp$bloco_id, resp$torneio_id, sep = "|")
  )
  media_por <- function(g) as.numeric(stats::ave(y, g))
  anterior <- rep(mean(y), length(y))
  n_anterior <- 1
  sq <- numeric(0)
  gl <- numeric(0)
  for (nivel in names(niveis)) {
    atual <- media_por(niveis[[nivel]])
    n_atual <- length(unique(niveis[[nivel]]))
    sq[nivel] <- sum((atual - anterior)^2)
    gl[nivel] <- n_atual - n_anterior
    anterior <- atual
    n_anterior <- n_atual
  }
  sq["dentro"] <- sum((y - anterior)^2)
  gl["dentro"] <- length(y) - n_anterior
  data.frame(
    componente = c(
      "entre estratos", "entre blocos (no estrato)", "entre torneios (na celula)",
      "dentro dos torneios"
    ),
    sq = as.numeric(sq), gl = as.numeric(gl), qm = as.numeric(sq / gl),
    proporcao = as.numeric(sq / sum(sq)),
    stringsAsFactors = FALSE
  )
}

#' Associacao entre a variavel e o buy-in do torneio (descritiva).
#'
#' Kruskal-Wallis entre estratos e Spearman com o buy-in do torneio, nos
#' respondentes, sem peso e tratando os jogadores como independentes. Os
#' p-valores ignoram a conglomeracao em torneios e blocos (sao otimistas).
#'
#' @param coleta data.frame de `carregar_coleta()`.
#' @param moldura data.frame de `montar_moldura()` (para o buy-in).
#' @param variavel character, coluna numerica.
#' @return data.frame com `teste`, `estatistica`, `p_valor`.
associar_buyin <- function(coleta, moldura, variavel) {
  resp <- coleta[coleta$respondeu %in% TRUE & !is.na(coleta[[variavel]]), , drop = FALSE]
  buy_in <- moldura$buy_in[match(resp$torneio_id, moldura$torneio_id)]
  if (anyNA(buy_in)) stop("Torneio da coleta ausente na moldura.")
  kw <- stats::kruskal.test(resp[[variavel]], factor(resp$estrato))
  sp <- suppressWarnings(stats::cor.test(resp[[variavel]], buy_in, method = "spearman"))
  data.frame(
    teste = c("Kruskal-Wallis (estratos)", "Spearman (buy-in)"),
    estatistica = c(unname(kw$statistic), unname(sp$estimate)),
    p_valor = c(kw$p.value, sp$p.value),
    stringsAsFactors = FALSE
  )
}

#' Compara, por estrato, a amostra aleatoria com o top 10 dos mesmos torneios.
#'
#' So os torneios em que o top 10 foi consultado, para comparar os mesmos
#' torneios. O top 10 fica fora do plano (ver `carregar_top10()`).
#'
#' @param coleta data.frame de `carregar_coleta()`.
#' @param top10 data.frame de `carregar_top10()`, com `respondeu` e `roi`.
#' @param moldura data.frame de `montar_moldura()` (para o estrato).
#' @return data.frame com `estrato`, `grupo` (`"amostra"` ou `"top10"`),
#'   `consultados`, `taxa_resposta`, `respondentes`, `roi_mediana` e
#'   `prop_lucrativos` (ROI > 0).
comparar_top10_estratos <- function(coleta, top10, moldura) {
  top10 <- top10[!is.na(top10$respondeu), , drop = FALSE]
  top10$estrato <- moldura$estrato[match(top10$torneio_id, moldura$torneio_id)]
  amostra <- coleta[coleta$torneio_id %in% top10$torneio_id & !is.na(coleta$respondeu), ,
    drop = FALSE
  ]
  grupos <- list(amostra = amostra, top10 = top10)
  linhas <- list()
  for (g in names(grupos)) {
    for (h in ORDEM_ESTRATOS) {
      d <- grupos[[g]][grupos[[g]]$estrato == h, , drop = FALSE]
      if (nrow(d) == 0) next
      roi <- d$roi[d$respondeu]
      linhas[[length(linhas) + 1]] <- data.frame(
        estrato = h, grupo = g, consultados = nrow(d),
        taxa_resposta = mean(d$respondeu), respondentes = length(roi),
        roi_mediana = if (length(roi)) stats::median(roi) else NA_real_,
        prop_lucrativos = if (length(roi)) mean(roi > 0) else NA_real_,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, linhas)
}

# ---------------------------------------------------------------------------
# Graficos (base R). Desenham no dispositivo aberto; quem chama abre e fecha.
# ---------------------------------------------------------------------------

#' Deslocamento horizontal deterministico para pontos sobrepostos.
#'
#' Sem RNG: ordena os valores e espalha em 5 colunas.
#'
#' @param y numeric.
#' @param largura numeric, meia largura maxima.
#' @return numeric, deslocamento por ponto (na ordem de `y`).
espalhar_pontos <- function(y, largura = 0.18) {
  pos <- (rank(y, ties.method = "first") - 1) %% 5
  (pos - 2) / 2 * largura
}

#' Eixos e grade discretos, no estilo de todos os graficos da AED.
#'
#' @param rotulos character, rotulos do eixo x (um por estrato).
#' @param log character, `"y"` se o eixo y e logaritmico.
#' @return NULL, invisivelmente.
desenhar_eixos <- function(rotulos, log = "") {
  marcas <- graphics::axTicks(2, log = log == "y")
  graphics::abline(h = marcas, col = "grey90", lwd = 1)
  graphics::axis(1, at = seq_along(rotulos), labels = rotulos, tick = FALSE, col.axis = "grey20")
  graphics::axis(2, at = marcas, labels = format(marcas, big.mark = ".", decimal.mark = ","),
    las = 1, tick = FALSE, col.axis = "grey30"
  )
  invisible(NULL)
}

#' Pontos por estrato (uma coluna por estrato, cor do estrato).
#'
#' @param y numeric.
#' @param estrato character.
#' @param titulo character.
#' @param log character, `""` ou `"y"`.
#' @param ylim numeric(2) ou NULL.
#' @param linha_mediana logical, se desenha um traco na mediana.
#' @param medianas numeric nomeado por estrato, ou NULL (calcula de `y`).
#' @return NULL, invisivelmente.
pontos_por_estrato <- function(y, estrato, titulo, log = "", ylim = NULL,
                               linha_mediana = TRUE, medianas = NULL) {
  f <- fator_estrato(estrato)
  x <- as.integer(f)
  if (is.null(ylim)) ylim <- range(y)
  graphics::plot(NA,
    xlim = c(0.5, length(ORDEM_ESTRATOS) + 0.5), ylim = ylim, log = log,
    axes = FALSE, xlab = "", ylab = "", main = ""
  )
  graphics::title(main = titulo, adj = 0, font.main = 1, cex.main = 1, col.main = "grey10")
  desenhar_eixos(NOMES_ESTRATOS[ORDEM_ESTRATOS], log)
  dx <- stats::ave(y, f, FUN = espalhar_pontos)
  graphics::points(x + dx, y,
    pch = 21, bg = CORES_ESTRATOS[as.character(f)], col = "white",
    cex = 1.3, lwd = 1
  )
  if (linha_mediana) {
    med <- if (is.null(medianas)) tapply(y, f, stats::median) else medianas[ORDEM_ESTRATOS]
    graphics::segments(seq_along(med) - 0.3, med, seq_along(med) + 0.3, med,
      lwd = 2, col = "grey15"
    )
  }
  invisible(NULL)
}

#' Moldura por estrato: buy-in e inscritos por torneio (escala log).
#'
#' @param moldura data.frame de `montar_moldura()`.
#' @return NULL, invisivelmente.
grafico_moldura_estratos <- function(moldura) {
  antigo <- graphics::par(mfrow = c(1, 2), mar = c(3, 4.5, 3, 1), family = "sans")
  on.exit(graphics::par(antigo))
  pontos_por_estrato(moldura$buy_in, moldura$estrato, "Buy-in do torneio (US$, log)", log = "y")
  pontos_por_estrato(moldura$n_inscritos, moldura$estrato, "Inscritos por torneio (M_k, log)",
    log = "y"
  )
  invisible(NULL)
}

#' ROI dos respondentes por estrato, com recorte do eixo para a cauda.
#'
#' Pontos acima de `teto` sao desenhados no teto (triangulo) e rotulados com o
#' valor real, para a cauda nao achatar o resto do grafico. A mediana usa
#' todos os pontos.
#'
#' @param coleta data.frame de `carregar_coleta()`.
#' @param teto numeric, limite superior do eixo (% de ROI).
#' @return NULL, invisivelmente.
grafico_roi_estratos <- function(coleta, teto = 100) {
  resp <- coleta[coleta$respondeu %in% TRUE, , drop = FALSE]
  antigo <- graphics::par(mar = c(3, 4.5, 3, 1), family = "sans")
  on.exit(graphics::par(antigo))
  fora <- resp$roi > teto
  medianas <- tapply(resp$roi, fator_estrato(resp$estrato), stats::median)
  pontos_por_estrato(resp$roi[!fora], resp$estrato[!fora],
    "ROI dos respondentes (%), mediana em traço",
    ylim = c(min(resp$roi, 0), teto), medianas = medianas
  )
  graphics::abline(h = 0, col = "grey40", lwd = 1)
  if (any(fora)) {
    x <- as.integer(fator_estrato(resp$estrato[fora]))
    graphics::points(x, rep(teto, sum(fora)), pch = 24, bg = "grey15", col = "white", cex = 1.4)
    graphics::text(x + 0.08, teto,
      sprintf("%s%%", format(resp$roi[fora], decimal.mark = ",")),
      pos = 4, cex = 0.8, col = "grey20"
    )
  }
  invisible(NULL)
}

#' Taxa de resposta por estrato: amostra aleatoria vs. top 10.
#'
#' Duas series sem cor (a cor ja identifica o estrato): circulo cheio para a
#' amostra, vazado para o top 10, com legenda e valores rotulados.
#'
#' @param comparacao data.frame de `comparar_top10_estratos()`.
#' @return NULL, invisivelmente.
grafico_resposta_estratos <- function(comparacao) {
  antigo <- graphics::par(mar = c(3, 4.5, 3, 1), family = "sans")
  on.exit(graphics::par(antigo))
  graphics::plot(NA,
    xlim = c(0.5, length(ORDEM_ESTRATOS) + 0.5), ylim = c(0, 1),
    axes = FALSE, xlab = "", ylab = ""
  )
  graphics::title(
    main = "Taxa de resposta (perfil público) nos mesmos torneios",
    adj = 0, font.main = 1, cex.main = 1, col.main = "grey10"
  )
  desenhar_eixos(NOMES_ESTRATOS[ORDEM_ESTRATOS])
  estilos <- list(amostra = list(pch = 19, dx = -0.12), top10 = list(pch = 1, dx = 0.12))
  for (g in names(estilos)) {
    d <- comparacao[comparacao$grupo == g, , drop = FALSE]
    x <- as.integer(fator_estrato(d$estrato)) + estilos[[g]]$dx
    graphics::points(x, d$taxa_resposta,
      pch = estilos[[g]]$pch, cex = 1.6, lwd = 2,
      col = CORES_ESTRATOS[d$estrato]
    )
    graphics::text(x, d$taxa_resposta, sprintf("%.0f%%", 100 * d$taxa_resposta),
      pos = 3, offset = 0.8, cex = 0.8, col = "grey20"
    )
  }
  graphics::legend("bottomright",
    legend = c("amostra aleatória", "top 10"), pch = c(19, 1),
    pt.cex = 1.4, pt.lwd = 2, col = "grey30", bty = "n", cex = 0.85
  )
  invisible(NULL)
}
