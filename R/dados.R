#' Carregamento e validacao dos dados brutos.
#'
#' Sem transformacao de negocio aqui -- so leitura, tipagem e validacao
#' estrutural. Duas fontes:
#'   - Kaggle (populacao conhecida, `data/raw/kaggle/`);
#'   - SharkScope (listagem de torneios, top 10 e coleta de campo,
#'     `data/raw/sharkscope/`).

COLUNAS_LISTAGEM <- c(
  "bloco_id", "torneio_id", "nome", "inicio_fonte", "fuso_fonte", "inicio_brasilia",
  "tipo", "buy_in", "n_entradas_fonte", "status", "motivo_exclusao", "fonte",
  "data_listagem", "observacao"
)
COLUNAS_TOP10 <- c("bloco_id", "torneio_id", "posicao", "nickname", "data_anotacao")
COLUNAS_COLETA <- c(
  "estrato", "torneio_id", "n_inscritos", "nickname", "respondeu", "roi", "lucro"
)

#' Valida se um data.frame tem as colunas esperadas.
#'
#' @param df data.frame a validar.
#' @param esperadas character, nomes de colunas obrigatorias.
#' @param origem character, nome da fonte (so para a mensagem de erro).
#' @return `df`, invisivelmente, se valido; erro caso contrario.
validar_colunas <- function(df, esperadas, origem) {
  faltando <- setdiff(esperadas, names(df))
  if (length(faltando) > 0) {
    stop(sprintf(
      "Colunas faltando em %s: %s. Colunas disponiveis: %s",
      origem, paste(sort(faltando), collapse = ", "), paste(names(df), collapse = ", ")
    ))
  }
  invisible(df)
}

COLUNAS_KAGGLE <- c(
  "player_id", "skill", "avg_buyin", "realized_roi", "went_broke", "profitable"
)

# Limites das faixas de buy-in (US$), iguais aos estratos de campo (plano §3.1):
# [0, 5) micro, [5, 25) low, [25, Inf) mid_high.
LIMITES_BUYIN <- c(0, 5, 25, Inf)
ROTULOS_BUYIN <- c("micro", "low", "mid_high")

#' Classifica buy-ins nas faixas de estratificacao do plano (§3.1).
#'
#' @param buy_in numeric, buy-in em US$.
#' @return character com `"micro"`, `"low"` ou `"mid_high"`.
estratificar_buyin <- function(buy_in) {
  as.character(cut(buy_in, LIMITES_BUYIN, labels = ROTULOS_BUYIN, right = FALSE))
}

#' Le o dataset do Kaggle e padroniza as colunas usadas na simulacao.
#'
#' Dataset "Poker Tournament Survival -- Skill vs. Variance" (45.000
#' jogadores, 17 colunas; ver `data/raw/README.md`). A unidade e o jogador,
#' com o historico agregado de varios torneios, como num perfil do SharkScope.
#' Nao ha identificador de torneio.
#'
#' @param caminho character, caminho de `poker_tournament_survival.csv`.
#' @param estratificar_por character: `"buyin"` (faixas de `avg_buyin`, as
#'   mesmas do campo), `"skill"` (quartis de `skill`, variavel latente que nao
#'   e observavel em campo -- so para fins didaticos) ou `"nenhum"`.
#' @return data.frame com `player_id`, `roi` (= `realized_roi`, em %),
#'   `lucrativo` (= `profitable`, 1 se ROI > 0), `skill`, `avg_buyin`,
#'   `went_broke` e, se pedido, `estrato`.
carregar_populacao_kaggle <- function(caminho, estratificar_por = c("buyin", "skill", "nenhum")) {
  estratificar_por <- match.arg(estratificar_por)
  bruto <- read.csv(caminho, stringsAsFactors = FALSE)
  validar_colunas(bruto, COLUNAS_KAGGLE, "dataset do Kaggle")

  populacao <- data.frame(
    player_id = bruto$player_id,
    roi = as.numeric(bruto$realized_roi),
    lucrativo = as.integer(bruto$profitable),
    skill = as.numeric(bruto$skill),
    avg_buyin = as.numeric(bruto$avg_buyin),
    went_broke = as.integer(bruto$went_broke),
    stringsAsFactors = FALSE
  )
  if (estratificar_por == "buyin") {
    populacao$estrato <- estratificar_buyin(populacao$avg_buyin)
  } else if (estratificar_por == "skill") {
    quartis <- stats::quantile(populacao$skill, c(0, 0.25, 0.5, 0.75, 1))
    populacao$estrato <- as.character(cut(
      populacao$skill, quartis,
      labels = paste0("skill_q", 1:4), include.lowest = TRUE
    ))
  }
  populacao[!is.na(populacao$roi), , drop = FALSE]
}

#' Le a listagem dos torneios dos blocos sorteados (Metodologia §6, Fase 1).
#'
#' Uma linha por torneio com inicio dentro de um bloco sorteado, inclusive os
#' excluidos da populacao (`motivo_exclusao` preenchido). Formato em
#' `data/raw/README.md`.
#'
#' @param caminho character, CSV com as colunas de `COLUNAS_LISTAGEM`.
#' @return data.frame tipado, com a coluna derivada `elegivel`.
carregar_listagem <- function(caminho) {
  listagem <- read.csv(
    caminho,
    colClasses = c(torneio_id = "character", motivo_exclusao = "character"),
    stringsAsFactors = FALSE
  )
  validar_colunas(listagem, COLUNAS_LISTAGEM, "listagem de torneios")
  listagem$bloco_id <- as.integer(listagem$bloco_id)
  listagem$buy_in <- as.numeric(listagem$buy_in)
  listagem$n_entradas_fonte <- as.integer(listagem$n_entradas_fonte)
  listagem$motivo_exclusao[is.na(listagem$motivo_exclusao)] <- ""
  listagem$elegivel <- trimws(listagem$motivo_exclusao) == ""
  if (anyDuplicated(listagem$torneio_id)) stop("torneio_id duplicado na listagem.")
  listagem
}

#' Monta a moldura de torneios elegiveis a partir da listagem.
#'
#' Fica so com os torneios sem `motivo_exclusao` e classifica cada um no
#' estrato de buy-in. `n_inscritos` (M_k) e o total de entradas da fonte
#' (`n_entradas_fonte`), com re-entries: simplificacao adotada no projeto
#' (Metodologia §2.4).
#'
#' @param listagem data.frame (ver `carregar_listagem()`).
#' @return data.frame com `bloco_id`, `estrato`, `torneio_id`, `buy_in` e
#'   `n_inscritos`.
montar_moldura <- function(listagem) {
  elegiveis <- listagem[listagem$elegivel, , drop = FALSE]
  data.frame(
    bloco_id = elegiveis$bloco_id,
    estrato = estratificar_buyin(elegiveis$buy_in),
    torneio_id = elegiveis$torneio_id,
    buy_in = elegiveis$buy_in,
    n_inscritos = elegiveis$n_entradas_fonte,
    stringsAsFactors = FALSE
  )
}

#' Le o top 10 dos torneios sorteados (fora do plano amostral).
#'
#' Os 10 primeiros colocados de cada torneio sorteado, anotados para uma
#' comparacao futura com a amostra aleatoria. Nao entram nos estimadores.
#'
#' @param caminho character, CSV com as colunas de `COLUNAS_TOP10`.
#' @return data.frame tipado; erro se houver posicao fora de 1 a 10 ou
#'   repetida no mesmo torneio.
carregar_top10 <- function(caminho) {
  top10 <- read.csv(caminho, stringsAsFactors = FALSE, colClasses = c(torneio_id = "character"))
  validar_colunas(top10, COLUNAS_TOP10, "top 10 dos torneios")
  top10$posicao <- as.integer(top10$posicao)
  if (any(!top10$posicao %in% 1:10)) stop("posicao fora de 1 a 10 no top 10.")
  if (anyDuplicated(top10[, c("torneio_id", "posicao")])) {
    stop("posicao repetida no mesmo torneio no top 10.")
  }
  top10
}

COLUNAS_LOG <- c("registrado_em", "fase", "evento", "detalhe", "seed")

#' Acrescenta um evento ao log de coleta (Metodologia §6, "Registro").
#'
#' Todo sorteio, substituicao e nao resposta vira uma linha. Cria o arquivo
#' com cabecalho se ele ainda nao existir.
#'
#' @param caminho character, caminho de `log_coleta.csv`.
#' @param fase character, fase do protocolo (ex.: `"0"`).
#' @param evento character, tipo do evento (ex.: `"sorteio_blocos"`).
#' @param detalhe character, descricao livre do evento.
#' @param seed integer ou `NA`, semente usada (se houver).
#' @return a linha registrada (data.frame), invisivelmente.
registrar_log_coleta <- function(caminho, fase, evento, detalhe, seed = NA_integer_) {
  linha <- data.frame(
    registrado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    fase = as.character(fase),
    evento = evento,
    detalhe = detalhe,
    seed = as.integer(seed),
    stringsAsFactors = FALSE
  )
  existe <- file.exists(caminho)
  utils::write.table(
    linha, caminho,
    sep = ",", row.names = FALSE, col.names = !existe, append = existe, qmethod = "double"
  )
  invisible(linha)
}

#' Le a planilha de coleta de campo no SharkScope.
#'
#' Cada linha e um jogador consultado (titular ou reserva). `respondeu` e
#' `FALSE` quando o perfil e privado (nao resposta, ver plano §5.1).
#'
#' @param caminho character, CSV com as colunas de `COLUNAS_COLETA`.
#' @return data.frame tipado, com a coluna derivada `lucrativo`.
carregar_coleta <- function(caminho) {
  coleta <- read.csv(caminho, stringsAsFactors = FALSE)
  validar_colunas(coleta, COLUNAS_COLETA, "coleta de campo")
  coleta$estrato <- as.character(coleta$estrato)
  coleta$torneio_id <- as.character(coleta$torneio_id)
  coleta$respondeu <- as.logical(coleta$respondeu)
  coleta$lucrativo <- as.integer(coleta$roi > 0)
  if ("n_jogos_dia" %in% names(coleta)) coleta$n_jogos_dia <- as.numeric(coleta$n_jogos_dia)
  coleta
}
