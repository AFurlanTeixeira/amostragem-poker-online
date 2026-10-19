#' Carregamento e validacao dos dados brutos.
#'
#' Sem transformacao de negocio aqui -- so leitura, tipagem e validacao
#' estrutural. Duas fontes:
#'   - Kaggle (populacao conhecida, `data/raw/kaggle/`);
#'   - SharkScope (moldura de torneios, inscritos e coleta de campo,
#'     `data/raw/sharkscope/`).

COLUNAS_MOLDURA <- c("estrato", "torneio_id", "buy_in", "n_inscritos")
COLUNAS_INSCRITOS <- c("torneio_id", "nickname")
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

#' Le a moldura de torneios do periodo de referencia (1o estagio).
#'
#' @param caminho character, CSV com `estrato`, `torneio_id`, `buy_in`,
#'   `n_inscritos` (uma linha por torneio da populacao).
#' @return data.frame tipado.
carregar_moldura <- function(caminho) {
  moldura <- read.csv(caminho, stringsAsFactors = FALSE)
  validar_colunas(moldura, COLUNAS_MOLDURA, "moldura de torneios")
  moldura$estrato <- as.character(moldura$estrato)
  moldura$torneio_id <- as.character(moldura$torneio_id)
  moldura$n_inscritos <- as.integer(moldura$n_inscritos)
  if (anyDuplicated(moldura$torneio_id)) stop("torneio_id duplicado na moldura.")
  moldura
}

#' Le a lista de inscritos dos torneios sorteados (2o estagio).
#'
#' @param caminho character, CSV com `torneio_id` e `nickname`.
#' @return data.frame tipado.
carregar_inscritos <- function(caminho) {
  inscritos <- read.csv(caminho, stringsAsFactors = FALSE)
  validar_colunas(inscritos, COLUNAS_INSCRITOS, "lista de inscritos")
  inscritos$torneio_id <- as.character(inscritos$torneio_id)
  inscritos
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
  coleta
}
