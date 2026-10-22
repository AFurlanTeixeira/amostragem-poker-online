#' Sorteio da amostra de campo (estratificada em tres estagios, Metodologia §4).
#'
#' 1o estagio (Metodologia §6, Fase 0): AAS sem reposicao de blocos de
#' tempo de 2 h do periodo de referencia.
#' 2o estagio: torneios, AAS sem reposicao dentro de cada celula (bloco, estrato).
#' 3o estagio: jogadores, AAS sem reposicao de posicoes da lista de resultados de
#' cada torneio sorteado, com lista ordenada de reserva opcional (no projeto,
#' m_k = 5 e nenhuma reserva; ADR-010).

B_MINIMO <- 2 # necessario para estimar a variancia entre blocos (Metodologia §8.1)
N_MINIMO_POR_ESTRATO <- 2 # necessario para estimar a variancia entre torneios
M_MINIMO_POR_TORNEIO <- 2 # necessario para estimar a variancia dentro do torneio

#' Gera a lista dos B blocos de tempo do periodo (Fase 0, passo 1).
#'
#' Moldura do estagio temporal (Metodologia §3): o periodo [inicio, fim) e
#' dividido em blocos consecutivos de `horas_por_bloco` horas, com
#' B = (fim - inicio) / horas_por_bloco (76 h / 2 h = 38 no plano).
#'
#' @param inicio,fim character, `"AAAA-MM-DD"` ou `"AAAA-MM-DD HH:MM"` no
#'   `fuso`; a duracao do periodo deve ser multipla de `horas_por_bloco`.
#' @param horas_por_bloco integer, duracao de cada bloco (divisor de 24).
#' @param fuso character, fuso horario dos horarios (nome IANA).
#' @return data.frame com `bloco_id` (1 a B, em ordem cronologica), `inicio`
#'   e `fim` (`"AAAA-MM-DD HH:MM"` no `fuso`), `inicio_utc` (ISO 8601),
#'   `dia_semana` (1 = segunda, 7 = domingo), `fim_de_semana` e `fuso`.
gerar_blocos <- function(inicio, fim, horas_por_bloco = 2, fuso = "America/Sao_Paulo") {
  if (24 %% horas_por_bloco != 0) stop("horas_por_bloco deve dividir 24.")
  passo <- horas_por_bloco * 3600
  primeiro <- as.POSIXct(inicio, tz = fuso)
  duracao <- as.numeric(difftime(as.POSIXct(fim, tz = fuso), primeiro, units = "secs"))
  if (duracao <= 0 || duracao %% passo != 0) {
    stop("A duracao do periodo deve ser multipla positiva de horas_por_bloco.")
  }
  B <- as.integer(duracao / passo)
  inicios <- primeiro + passo * (seq_len(B) - 1)
  fins <- inicios + passo
  dia_semana <- as.integer(format(inicios, "%u"))

  data.frame(
    bloco_id = seq_len(B),
    inicio = format(inicios, "%Y-%m-%d %H:%M"),
    fim = format(fins, "%Y-%m-%d %H:%M"),
    inicio_utc = format(inicios, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    dia_semana = dia_semana,
    fim_de_semana = dia_semana >= 6,
    fuso = fuso,
    stringsAsFactors = FALSE
  )
}

#' Sorteia os blocos de tempo (UPA do 1o estagio; Fase 0, passo 2).
#'
#' AAS sem reposicao de b blocos entre os B da moldura, com probabilidade de
#' inclusao b/B (primeiro fator de pi_jhki, Metodologia §7.4).
#'
#' @param blocos data.frame (ver `gerar_blocos()`).
#' @param b integer, numero de blocos a sortear.
#' @param seed integer, semente do sorteio.
#' @return subconjunto de `blocos` em ordem cronologica, com `ordem_sorteio`
#'   (ordem em que cada bloco saiu), `B`, `b` e `seed`.
sortear_blocos <- function(blocos, b, seed) {
  if (b < B_MINIMO) stop(sprintf("Sorteie ao menos %d blocos.", B_MINIMO))
  if (b > nrow(blocos)) stop(sprintf("A moldura tem so %d blocos.", nrow(blocos)))

  sorteio <- withr_seed(seed, sample.int(nrow(blocos), b))
  sorteados <- blocos[sorteio, , drop = FALSE]
  sorteados$ordem_sorteio <- seq_len(b)
  sorteados$B <- nrow(blocos)
  sorteados$b <- as.integer(b)
  sorteados$seed <- as.integer(seed)
  sorteados <- sorteados[order(sorteados$bloco_id), , drop = FALSE]
  rownames(sorteados) <- NULL
  sorteados
}

#' Sorteia os torneios em cada celula (bloco, estrato) (Metodologia §6, passo 5).
#'
#' AAS sem reposicao de n_jh torneios entre os N_jh da celula. Se a celula
#' tiver N_jh <= n_jh torneios, todos entram (censo da celula, com fator de
#' correcao para populacao finita igual a zero).
#'
#' Cada celula usa uma semente derivada de `seed` e da propria celula
#' (`semente_derivada()`), entao o sorteio de um bloco nao muda quando outros
#' blocos entram na listagem depois (coleta em lotes).
#'
#' @param moldura data.frame (ver `montar_moldura()`), com `bloco_id`,
#'   `estrato` e `torneio_id`.
#' @param n_por_estrato integer: um valor para todos os estratos ou um vetor
#'   nomeado por estrato; vale em cada bloco.
#' @param seed integer, semente do sorteio.
#' @return subconjunto de `moldura` com os torneios sorteados e as colunas
#'   `N_jh` (torneios da celula na moldura) e `n_jh` (sorteados na celula).
sortear_torneios <- function(moldura, n_por_estrato, seed) {
  estratos <- sort(unique(moldura$estrato))
  n_h <- expandir_por_estrato(n_por_estrato, estratos)
  if (any(n_h < N_MINIMO_POR_ESTRATO)) {
    stop(sprintf("Sorteie ao menos %d torneios por estrato.", N_MINIMO_POR_ESTRATO))
  }
  celulas <- unique(moldura[order(moldura$bloco_id, moldura$estrato), c("bloco_id", "estrato")])

  partes <- lapply(seq_len(nrow(celulas)), function(i) {
    h <- celulas$estrato[i]
    na_celula <- moldura$bloco_id == celulas$bloco_id[i] & moldura$estrato == h
    da_celula <- moldura[na_celula, , drop = FALSE]
    tamanho <- min(n_h[[h]], nrow(da_celula))
    semente <- semente_derivada(seed, paste(celulas$bloco_id[i], h))
    linhas <- withr_seed(semente, sample.int(nrow(da_celula), tamanho))
    sorteados <- da_celula[linhas, , drop = FALSE]
    sorteados$N_jh <- nrow(da_celula)
    sorteados$n_jh <- tamanho
    sorteados
  })
  resultado <- do.call(rbind, partes)
  rownames(resultado) <- NULL
  resultado
}

#' Sorteia os jogadores (USA) dentro de cada torneio sorteado, por posicao.
#'
#' Em vez de transcrever a lista de inscritos, sorteia posicoes de 1 a M_k
#' (`n_inscritos`) na lista de resultados da fonte, que ja tem ordem fixa
#' (1 = campeao). Os `m` primeiros sorteados sao os titulares e os
#' `n_reserva` seguintes, a reserva (na ordem em que deve ser usada). Na
#' coleta, a posicao que nao existir na lista ou repetir um jogador ja
#' sorteado no torneio e pulada, e a proxima da ordem e usada.
#'
#' Cada torneio usa uma semente derivada de `seed` e do `torneio_id`, entao o
#' sorteio de um torneio nao depende dos outros torneios do arquivo. Como
#' `sample.int()` sem reposicao sorteia em sequencia, aumentar `n_reserva`
#' depois so acrescenta posicoes ao fim da ordem, sem mudar as anteriores.
#'
#' @param torneios data.frame com `torneio_id` e `n_inscritos` (ver
#'   `torneios_sorteados.csv`); as demais colunas sao mantidas.
#' @param m_por_torneio integer, jogadores titulares por torneio.
#' @param n_reserva integer, tamanho da lista de reserva por torneio.
#' @param seed integer, semente do sorteio.
#' @return data.frame com as colunas de `torneios` mais `ordem`, `posicao`
#'   e `tipo` (`"titular"` ou `"reserva"`), uma linha por posicao sorteada.
sortear_jogadores <- function(torneios, m_por_torneio, n_reserva, seed) {
  if (m_por_torneio < M_MINIMO_POR_TORNEIO) {
    stop(sprintf("Sorteie ao menos %d jogadores por torneio.", M_MINIMO_POR_TORNEIO))
  }

  partes <- lapply(seq_len(nrow(torneios)), function(i) {
    k <- torneios$torneio_id[i]
    M_k <- torneios$n_inscritos[i]
    tamanho <- min(M_k, m_por_torneio + n_reserva)
    posicoes <- withr_seed(semente_derivada(seed, k), sample.int(M_k, tamanho))
    linhas <- torneios[rep(i, tamanho), , drop = FALSE]
    linhas$ordem <- seq_len(tamanho)
    linhas$posicao <- posicoes
    linhas$tipo <- ifelse(seq_len(tamanho) <= m_por_torneio, "titular", "reserva")
    linhas
  })
  resultado <- do.call(rbind, partes)
  rownames(resultado) <- NULL
  resultado
}

#' Deriva uma semente para uma unidade (celula ou torneio) a partir de `seed`.
#'
#' Combina `seed` com os codigos dos caracteres de `chave`, ponderados pela
#' posicao, modulo o maior inteiro do R. E deterministica e so depende da
#' propria unidade.
#'
#' @param seed integer, semente principal.
#' @param chave character(1), identificador da unidade.
#' @return integer.
semente_derivada <- function(seed, chave) {
  codigos <- utf8ToInt(as.character(chave))
  as.integer((seed + sum(codigos * seq_along(codigos)) * 7919) %% .Machine$integer.max)
}

#' Expande um tamanho de amostra escalar ou nomeado para todos os estratos.
#'
#' @param valor integer escalar ou vetor nomeado por estrato.
#' @param estratos character, estratos existentes.
#' @return vetor integer nomeado por estrato.
expandir_por_estrato <- function(valor, estratos) {
  if (is.null(names(valor))) {
    return(stats::setNames(rep(as.integer(valor), length(estratos)), estratos))
  }
  faltando <- setdiff(estratos, names(valor))
  if (length(faltando) > 0) stop("Tamanho nao informado para: ", paste(faltando, collapse = ", "))
  valor[estratos]
}

#' Avalia `codigo` com a semente `seed`, restaurando o estado do RNG depois.
#'
#' Equivalente minimo de `withr::with_seed()`, para nao adicionar dependencia.
#'
#' @param seed integer.
#' @param codigo expressao a avaliar.
#' @return o valor de `codigo`.
withr_seed <- function(seed, codigo) {
  tinha_seed <- exists(".Random.seed", envir = globalenv())
  if (tinha_seed) antigo <- get(".Random.seed", envir = globalenv())
  on.exit({
    if (tinha_seed) {
      assign(".Random.seed", antigo, envir = globalenv())
    } else if (exists(".Random.seed", envir = globalenv())) {
      rm(".Random.seed", envir = globalenv())
    }
  })
  set.seed(seed)
  codigo
}
