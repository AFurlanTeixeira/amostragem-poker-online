#' Sorteio da amostra de campo (estratificada em dois estagios).
#'
#' Estagio temporal (Metodologia §6, Fase 0): AAS sem reposicao de blocos de
#' tempo de 2 h do periodo de referencia.
#' 1o estagio: AAS sem reposicao de torneios dentro de cada estrato.
#' 2o estagio: AAS sem reposicao de jogadores dentro de cada torneio sorteado,
#' mais uma lista ordenada de reserva para substituir perfis privados
#' (plano §3.2, §3.3 e §5.1).

B_MINIMO <- 2 # necessario para estimar a variancia entre blocos (Metodologia §8.1)
N_MINIMO_POR_ESTRATO <- 2 # necessario para estimar a variancia entre torneios
M_MINIMO_POR_TORNEIO <- 2 # necessario para estimar a variancia dentro do torneio

#' Gera a lista dos B blocos de tempo do periodo (Fase 0, passo 1).
#'
#' Moldura do estagio temporal (Metodologia §3): o periodo e dividido em
#' blocos consecutivos de `horas_por_bloco` horas, com
#' B = n_dias * 24 / horas_por_bloco (14 * 12 = 168 no plano).
#'
#' @param inicio character, data de inicio do periodo (`"AAAA-MM-DD"`).
#' @param n_dias integer, numero de dias corridos do periodo.
#' @param horas_por_bloco integer, duracao de cada bloco (divisor de 24).
#' @param fuso character, fuso horario dos horarios (nome IANA).
#' @return data.frame com `bloco_id` (1 a B, em ordem cronologica), `inicio`
#'   e `fim` (`"AAAA-MM-DD HH:MM"` no `fuso`), `inicio_utc` (ISO 8601),
#'   `dia_semana` (1 = segunda, 7 = domingo), `fim_de_semana` e `fuso`.
gerar_blocos <- function(inicio, n_dias, horas_por_bloco = 2, fuso = "America/Sao_Paulo") {
  if (24 %% horas_por_bloco != 0) stop("horas_por_bloco deve dividir 24.")
  B <- as.integer(n_dias * 24 / horas_por_bloco)
  passo <- horas_por_bloco * 3600
  inicios <- as.POSIXct(inicio, tz = fuso) + passo * (seq_len(B) - 1)
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

#' Sorteia os torneios (UPA) em cada estrato.
#'
#' @param moldura data.frame (ver `carregar_moldura()`).
#' @param n_por_estrato integer: um valor para todos os estratos ou um vetor
#'   nomeado por estrato.
#' @param seed integer, semente do sorteio.
#' @return subconjunto de `moldura` com os torneios sorteados e a coluna
#'   `N_h` (numero de torneios do estrato na moldura).
sortear_torneios <- function(moldura, n_por_estrato, seed) {
  estratos <- sort(unique(moldura$estrato))
  n_h <- expandir_por_estrato(n_por_estrato, estratos)
  if (any(n_h < N_MINIMO_POR_ESTRATO)) {
    stop(sprintf("Sorteie ao menos %d torneios por estrato.", N_MINIMO_POR_ESTRATO))
  }

  withr_seed(seed, {
    partes <- lapply(estratos, function(h) {
      do_estrato <- moldura[moldura$estrato == h, , drop = FALSE]
      if (n_h[[h]] > nrow(do_estrato)) {
        stop(sprintf("Estrato %s tem so %d torneios.", h, nrow(do_estrato)))
      }
      sorteados <- do_estrato[sample.int(nrow(do_estrato), n_h[[h]]), , drop = FALSE]
      sorteados$N_h <- nrow(do_estrato)
      sorteados
    })
  })
  resultado <- do.call(rbind, partes)
  rownames(resultado) <- NULL
  resultado
}

#' Sorteia os jogadores (USA) dentro de cada torneio sorteado.
#'
#' Sorteia uma permutacao aleatoria dos inscritos: os `m` primeiros sao os
#' titulares e os `n_reserva` seguintes, a lista de reserva (na ordem em que
#' devem ser usados).
#'
#' @param inscritos data.frame (ver `carregar_inscritos()`).
#' @param m_por_torneio integer, jogadores titulares por torneio.
#' @param n_reserva integer, tamanho da lista de reserva por torneio.
#' @param seed integer, semente do sorteio.
#' @return data.frame com `torneio_id`, `nickname`, `ordem` e `tipo`
#'   (`"titular"` ou `"reserva"`).
sortear_jogadores <- function(inscritos, m_por_torneio, n_reserva, seed) {
  if (m_por_torneio < M_MINIMO_POR_TORNEIO) {
    stop(sprintf("Sorteie ao menos %d jogadores por torneio.", M_MINIMO_POR_TORNEIO))
  }
  torneios <- sort(unique(inscritos$torneio_id))

  withr_seed(seed, {
    partes <- lapply(torneios, function(k) {
      nomes <- inscritos$nickname[inscritos$torneio_id == k]
      tamanho <- min(length(nomes), m_por_torneio + n_reserva)
      escolhidos <- nomes[sample.int(length(nomes), tamanho)]
      data.frame(
        torneio_id = k,
        nickname = escolhidos,
        ordem = seq_len(tamanho),
        tipo = ifelse(seq_len(tamanho) <= m_por_torneio, "titular", "reserva"),
        stringsAsFactors = FALSE
      )
    })
  })
  do.call(rbind, partes)
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
