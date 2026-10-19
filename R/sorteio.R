#' Sorteio da amostra de campo (estratificada em dois estagios).
#'
#' 1o estagio: AAS sem reposicao de torneios dentro de cada estrato.
#' 2o estagio: AAS sem reposicao de jogadores dentro de cada torneio sorteado,
#' mais uma lista ordenada de reserva para substituir perfis privados
#' (plano §3.2, §3.3 e §5.1).

N_MINIMO_POR_ESTRATO <- 2 # necessario para estimar a variancia entre torneios
M_MINIMO_POR_TORNEIO <- 2 # necessario para estimar a variancia dentro do torneio

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
