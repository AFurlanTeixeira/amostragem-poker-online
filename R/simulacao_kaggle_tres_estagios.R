#' Plano de campo em tres estagios aplicado ao dataset do Kaggle (ADR-013).
#'
#' O Kaggle nao tem horario nem ID de torneio (ADR-007), entao a estrutura do
#' campo e construida: B blocos, cada um com N_jh torneios por estrato de
#' buy-in e M_k inscritos por torneio reamostrados da listagem real do
#' SharkScope. Cada torneio e preenchido com jogadores do Kaggle do mesmo
#' estrato, com probabilidade proporcional a `tournaments_played`, e um
#' jogador pode estar em varios torneios. Assim f_i (inscricoes do jogador)
#' e conhecido e o parametro por jogador distinto tambem.
#'
#' Os sorteios e os estimadores sao os mesmos do campo: `sortear_blocos()`,
#' `sortear_torneios()`, `estender_torneios()`, `sortear_jogadores()` e
#' `estimar_media_tres_estagios()`.

# Estrato vizinho para colapsar uma celula que esgota os torneios (ADR-011).
VIZINHO_COLAPSO <- c(low = "micro", micro = "low", mid_high = "low")

#' Monta a populacao sintetica de inscricoes com a estrutura do campo.
#'
#' Para cada bloco j e estrato h: N_jh e sorteado entre os N_jh observados nos
#' blocos listados do campo, e cada M_k entre os M_k observados no estrato.
#' Os M_k lugares do torneio sao preenchidos por AAS sem reposicao, com
#' probabilidade proporcional a `n_torneios`, entre os jogadores do Kaggle do
#' estrato. A posicao na "lista de resultados" e a ordem do preenchimento.
#'
#' @param populacao data.frame (ver `carregar_populacao_kaggle()`), com
#'   `estrato` por buy-in e `n_torneios`.
#' @param moldura_campo data.frame (ver `montar_moldura()`), torneios
#'   elegiveis dos blocos listados no SharkScope.
#' @param B integer, blocos na populacao sintetica.
#' @param seed integer, semente.
#' @return lista com `torneios` (`bloco_id`, `estrato`, `torneio_id`,
#'   `n_inscritos`), `inscricoes` (uma linha por inscricao, com `posicao`,
#'   `player_id`, `roi`, `lucrativo` e `f_i`) e `jogadores` (cada jogador da
#'   populacao uma vez, com `f_i`).
montar_populacao_blocos <- function(populacao, moldura_campo, B, seed) {
  estratos <- sort(unique(moldura_campo$estrato))
  N_obs <- table(moldura_campo$bloco_id, moldura_campo$estrato)
  M_obs <- split(moldura_campo$n_inscritos, moldura_campo$estrato)
  linhas_h <- split(seq_len(nrow(populacao)), populacao$estrato)

  withr_seed(seed, {
    torneios <- do.call(rbind, lapply(seq_len(B), function(j) {
      do.call(rbind, lapply(estratos, function(h) {
        N <- as.integer(N_obs[sample.int(nrow(N_obs), 1), h])
        data.frame(
          bloco_id = j, estrato = h,
          torneio_id = sprintf("K%02d_%s_%02d", j, h, seq_len(N)),
          n_inscritos = M_obs[[h]][sample.int(length(M_obs[[h]]), N, replace = TRUE)],
          stringsAsFactors = FALSE
        )
      }))
    }))
    escolhidos <- lapply(seq_len(nrow(torneios)), function(k) {
      idx <- linhas_h[[torneios$estrato[k]]]
      M <- torneios$n_inscritos[k]
      if (M > length(idx)) stop("Torneio com mais inscritos que jogadores no estrato.")
      idx[sample.int(length(idx), M, prob = populacao$n_torneios[idx])]
    })
  })

  M <- torneios$n_inscritos
  linha <- unlist(escolhidos)
  inscricoes <- data.frame(
    bloco_id = rep(torneios$bloco_id, M),
    estrato = rep(torneios$estrato, M),
    torneio_id = rep(torneios$torneio_id, M),
    n_inscritos = rep(M, M),
    posicao = sequence(M),
    player_id = populacao$player_id[linha],
    roi = populacao$roi[linha],
    lucrativo = populacao$lucrativo[linha],
    stringsAsFactors = FALSE
  )
  f <- table(inscricoes$player_id)
  inscricoes$f_i <- as.numeric(f[inscricoes$player_id])
  colunas <- c("player_id", "roi", "lucrativo", "f_i")
  jogadores <- inscricoes[!duplicated(inscricoes$player_id), colunas]
  rownames(jogadores) <- NULL
  # Inicio de cada torneio em `inscricoes`, para achar a linha de uma posicao.
  inicio <- stats::setNames(cumsum(c(0, M[-length(M)])), torneios$torneio_id)
  list(torneios = torneios, inscricoes = inscricoes, jogadores = jogadores, inicio = inicio)
}

#' Parametros verdadeiros da populacao sintetica.
#'
#' Por jogador distinto: media simples sobre `jogadores` (cada um uma vez).
#' Por inscricao: media sobre `inscricoes`.
#'
#' @param pop lista de `montar_populacao_blocos()`.
#' @return data.frame com `unidade`, `variavel` e `valor`.
parametros_verdadeiros <- function(pop) {
  data.frame(
    unidade = rep(c("jogador", "inscricao"), each = 2),
    variavel = rep(c("roi", "lucrativo"), 2),
    valor = c(
      mean(pop$jogadores$roi), mean(pop$jogadores$lucrativo),
      mean(pop$inscricoes$roi), mean(pop$inscricoes$lucrativo)
    ),
    stringsAsFactors = FALSE
  )
}

#' Sorteia as posicoes dos torneios e monta a planilha de "coleta".
#'
#' Mesmo 3o estagio do campo (`sortear_jogadores()`, m_k posicoes sem
#' reserva). Com `taxas`, simula a nao resposta como Bernoulli por estrato
#' (aleatoria dentro da celula, a hipotese do ADR-011), com semente por torneio.
#'
#' @param pop lista de `montar_populacao_blocos()`.
#' @param torneios data.frame de torneios sorteados (`bloco_id`, `estrato`,
#'   `torneio_id`, `n_inscritos`).
#' @param m_k integer, posicoes por torneio.
#' @param seed integer, semente.
#' @param taxas numeric nomeado por estrato (taxa de nao resposta) ou `NULL`.
#' @return data.frame no formato de `coleta_jogadores.csv`, com `f_i`.
montar_coleta_kaggle <- function(pop, torneios, m_k, seed, taxas = NULL) {
  pos <- sortear_jogadores(
    torneios[, c("bloco_id", "estrato", "torneio_id", "n_inscritos")], m_k, 0, seed
  )
  ins <- pop$inscricoes[pop$inicio[pos$torneio_id] + pos$posicao, ]
  pos$player_id <- ins$player_id
  pos$roi <- ins$roi
  pos$lucrativo <- ins$lucrativo
  pos$f_i <- ins$f_i
  pos$respondeu <- TRUE
  if (!is.null(taxas)) {
    for (k in unique(pos$torneio_id)) {
      no_k <- pos$torneio_id == k
      u <- withr_seed(semente_derivada(seed, paste("nr", k)), stats::runif(sum(no_k)))
      taxa <- taxas[[estrato_original(pos$estrato[no_k][1])]]
      pos$respondeu[no_k] <- u >= taxa
    }
  }
  pos
}

#' Estrato de buy-in de um rotulo, inclusive de celula colapsada ("low+micro").
#'
#' @param estrato character(1).
#' @return character(1), o primeiro estrato do rotulo.
estrato_original <- function(estrato) {
  strsplit(estrato, "+", fixed = TRUE)[[1]][1]
}

#' Sorteio completo em tres estagios na populacao sintetica.
#'
#' @param pop lista de `montar_populacao_blocos()`.
#' @param b integer, blocos sorteados.
#' @param n_jh integer, torneios por celula.
#' @param m_k integer, posicoes por torneio.
#' @param seed integer, semente (a mesma em todos os estagios, como no campo).
#' @param taxas numeric nomeado por estrato ou `NULL` (sem nao resposta).
#' @return lista com `blocos`, `moldura` (torneios dos blocos sorteados),
#'   `sorteados` e `coleta`.
sortear_amostra_kaggle <- function(pop, b, n_jh, m_k, seed, taxas = NULL) {
  blocos <- sortear_blocos(data.frame(bloco_id = sort(unique(pop$torneios$bloco_id))), b, seed)
  moldura <- pop$torneios[pop$torneios$bloco_id %in% blocos$bloco_id, , drop = FALSE]
  rownames(moldura) <- NULL
  sorteados <- sortear_torneios(moldura, n_jh, seed)
  list(
    blocos = blocos$bloco_id[order(blocos$ordem_sorteio)],
    moldura = moldura,
    sorteados = sorteados,
    coleta = montar_coleta_kaggle(pop, sorteados, m_k, seed, taxas)
  )
}

#' Celulas com menos de 2 torneios com m_k >= 2 respondentes.
#'
#' @param amostra lista de `sortear_amostra_kaggle()`.
#' @return data.frame com `bloco_id`, `estrato` e `torneios_ok`.
celulas_abaixo_do_minimo <- function(amostra) {
  cel <- unique(amostra$sorteados[, c("bloco_id", "estrato")])
  r <- amostra$coleta[amostra$coleta$respondeu, , drop = FALSE]
  m <- table(r$torneio_id)
  ok <- names(m)[m >= M_MINIMO_POR_TORNEIO]
  cel$torneios_ok <- vapply(seq_len(nrow(cel)), function(i) {
    no_cel <- amostra$sorteados$bloco_id == cel$bloco_id[i] &
      amostra$sorteados$estrato == cel$estrato[i]
    sum(amostra$sorteados$torneio_id[no_cel] %in% ok)
  }, numeric(1))
  cel[cel$torneios_ok < N_MINIMO_POR_ESTRATO, , drop = FALSE]
}

#' Aplica a regra de torneios extras do campo (ADR-011) ate todas as celulas
#' terem 2 torneios com m_k >= 2.
#'
#' A cada rodada, cada celula abaixo do minimo recebe o proximo torneio da
#' permutacao (`estender_torneios()`), com m_k posicoes e a mesma nao
#' resposta simulada. Celula que esgota os N_jh torneios e colapsada com o
#' estrato vizinho do mesmo bloco (`VIZINHO_COLAPSO`).
#'
#' @param pop lista de `montar_populacao_blocos()`.
#' @param amostra lista de `sortear_amostra_kaggle()`.
#' @param m_k integer, posicoes por torneio.
#' @param seed integer, semente.
#' @param taxas numeric nomeado por estrato.
#' @return `amostra` atualizada, com `eventos` (data.frame dos extras e colapsos).
aplicar_torneios_extras <- function(pop, amostra, m_k, seed, taxas) {
  eventos <- list()
  repeat {
    falta <- celulas_abaixo_do_minimo(amostra)
    if (nrow(falta) == 0) break
    for (i in seq_len(nrow(falta))) {
      j <- falta$bloco_id[i]
      h <- falta$estrato[i]
      n_cel <- sum(amostra$sorteados$bloco_id == j & amostra$sorteados$estrato == h)
      N_cel <- sum(amostra$moldura$bloco_id == j & amostra$moldura$estrato == h)
      if (n_cel < N_cel) {
        antes <- nrow(amostra$sorteados)
        amostra$sorteados <- estender_torneios(amostra$moldura, amostra$sorteados, j, h, 1, seed)
        novos <- amostra$sorteados[-seq_len(antes), , drop = FALSE]
        amostra$coleta <- rbind(amostra$coleta, montar_coleta_kaggle(pop, novos, m_k, seed, taxas))
        eventos <- c(eventos, list(data.frame(
          bloco_id = j, estrato = h, evento = "torneio_extra", torneio_id = novos$torneio_id
        )))
      } else {
        if (grepl("+", h, fixed = TRUE)) stop("Celula colapsada continua abaixo do minimo.")
        amostra <- colapsar_celula(amostra, j, h)
        eventos <- c(eventos, list(data.frame(
          bloco_id = j, estrato = h, evento = "colapso", torneio_id = NA_character_
        )))
      }
    }
  }
  amostra$eventos <- if (length(eventos)) do.call(rbind, eventos) else NULL
  amostra
}

#' Colapsa a celula (j, h) com o estrato vizinho do mesmo bloco (ADR-011).
#'
#' O rotulo novo (ex.: "low+micro") vale na moldura, nos sorteados e na
#' coleta do bloco, e N_jh e n_jh passam a ser somados.
#'
#' @param amostra lista de `sortear_amostra_kaggle()`.
#' @param bloco_id integer.
#' @param estrato character.
#' @return `amostra` com o rotulo trocado.
colapsar_celula <- function(amostra, bloco_id, estrato) {
  vizinho <- VIZINHO_COLAPSO[[estrato]]
  rotulo <- paste(sort(c(estrato, vizinho)), collapse = "+")
  for (parte in c("moldura", "sorteados", "coleta")) {
    d <- amostra[[parte]]
    troca <- d$bloco_id == bloco_id & d$estrato %in% c(estrato, vizinho)
    d$estrato[troca] <- rotulo
    amostra[[parte]] <- d
  }
  amostra
}

#' Monte Carlo do plano em tres estagios na populacao sintetica.
#'
#' Em cada replica: AAS de b blocos, n_jh torneios por celula e m_k posicoes
#' por torneio (sem nao resposta), e as estimativas por jogador e por
#' inscricao. Para o EPA empirico, cada replica tambem tira uma AAS de mesmo
#' n da populacao de jogadores (por jogador) ou de inscricoes (por inscricao).
#'
#' @param pop lista de `montar_populacao_blocos()`.
#' @param b integer, blocos por replica.
#' @param n_rep integer, numero de replicas.
#' @param seed integer, semente; a replica r usa `seed + r`.
#' @param n_jh,m_k integer, tamanhos do 2o e do 3o estagio.
#' @param nivel numeric, nivel de confianca.
#' @return data.frame com uma linha por replica, plano, unidade e variavel:
#'   `estimativa`, `variancia`, `li`, `ls`, `li_logit`, `ls_logit`, `epa_estimado`.
simular_tres_estagios <- function(pop, b, n_rep, seed, n_jh = 2, m_k = 5, nivel = 0.95) {
  B <- length(unique(pop$torneios$bloco_id))
  linhas <- lapply(seq_len(n_rep), function(r) {
    s <- seed + r
    amostra <- sortear_amostra_kaggle(pop, b, n_jh, m_k, s)
    n <- nrow(amostra$coleta)
    do.call(rbind, lapply(c("jogador", "inscricao"), function(u) {
      base <- if (u == "jogador") pop$jogadores else pop$inscricoes
      aas_idx <- withr_seed(semente_derivada(s, paste("aas", u)), sample.int(nrow(base), n))
      do.call(rbind, lapply(c("roi", "lucrativo"), function(v) {
        res <- estimar_media_tres_estagios(
          amostra$coleta, amostra$moldura, B, v, unidade = u, nivel = nivel
        )
        aas <- estimar_media_aas(base[[v]][aas_idx], nrow(base), nivel = nivel)
        epa <- calcular_epa_tres_estagios(res)$epa
        rbind(
          linha_tres_estagios(r, b, "tres_estagios", u, v, res, epa),
          linha_tres_estagios(r, b, "AAS", u, v, aas, NA_real_)
        )
      }))
    }))
  })
  do.call(rbind, linhas)
}

#' Uma linha do Monte Carlo, com o IC de Wald e, para proporcoes, o logit.
#'
#' @param r,b integer, replica e blocos.
#' @param plano,unidade,variavel character.
#' @param res lista de `montar_resultado()`.
#' @param epa numeric, EPA estimado na replica (ou `NA`).
#' @return data.frame de uma linha.
linha_tres_estagios <- function(r, b, plano, unidade, variavel, res, epa) {
  logit <- if (variavel == "roi") c(li = NA_real_, ls = NA_real_) else ic_logit(res)
  data.frame(
    replica = r, b = b, plano = plano, unidade = unidade, variavel = variavel,
    estimativa = res$estimativa, variancia = res$variancia, li = res$li, ls = res$ls,
    li_logit = logit[["li"]], ls_logit = logit[["ls"]], epa_estimado = epa,
    stringsAsFactors = FALSE
  )
}

#' Resume o Monte Carlo contra os parametros verdadeiros.
#'
#' Vies, variancia de Monte Carlo, media da variancia estimada, EQM, cobertura
#' dos IC (Wald e logit) e EPA empirico = Var_MC(plano) / Var_MC(AAS de mesmo
#' n) (Bolfarine & Bussab §3.4), ao lado da media do EPA estimado em cada replica.
#'
#' @param sims data.frame de `simular_tres_estagios()`.
#' @param verdade data.frame de `parametros_verdadeiros()`.
#' @return data.frame com uma linha por b, plano, unidade e variavel.
resumir_tres_estagios <- function(sims, verdade) {
  grupos <- unique(sims[, c("b", "plano", "unidade", "variavel")])
  resumo <- do.call(rbind, lapply(seq_len(nrow(grupos)), function(i) {
    g <- grupos[i, ]
    no_grupo <- sims$b == g$b & sims$plano == g$plano & sims$unidade == g$unidade
    s <- sims[no_grupo & sims$variavel == g$variavel, ]
    theta <- verdade$valor[verdade$unidade == g$unidade & verdade$variavel == g$variavel]
    # IC logit indefinido (estimativa 0 ou 1) conta como nao cobrir.
    cobre_logit <- !is.na(s$li_logit) & s$li_logit <= theta & theta <= s$ls_logit
    data.frame(
      g,
      parametro = theta,
      media_estimativas = mean(s$estimativa),
      vies = mean(s$estimativa) - theta,
      variancia_mc = stats::var(s$estimativa),
      media_var_estimada = mean(s$variancia),
      eqm = mean((s$estimativa - theta)^2),
      cobertura_wald = mean(s$li <= theta & theta <= s$ls),
      cobertura_logit = if (g$variavel == "roi") NA_real_ else mean(cobre_logit),
      ls_acima_de_1 = if (g$variavel == "roi") NA_real_ else mean(s$ls > 1),
      epa_estimado_medio = mean(s$epa_estimado),
      stringsAsFactors = FALSE
    )
  }))
  chave <- paste(resumo$b, resumo$unidade, resumo$variavel)
  ref <- resumo$variancia_mc[resumo$plano == "AAS"]
  names(ref) <- chave[resumo$plano == "AAS"]
  resumo$epa_empirico <- resumo$variancia_mc / ref[chave]
  rownames(resumo) <- NULL
  resumo
}
