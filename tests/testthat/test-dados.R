# Testes de `R/dados.R`.

escrever_csv <- function(df) {
  caminho <- tempfile(fileext = ".csv")
  write.csv(df, caminho, row.names = FALSE)
  caminho
}

test_that("validar_colunas aponta as colunas faltando", {
  expect_error(validar_colunas(data.frame(a = 1), c("a", "b"), "teste"), "faltando em teste: b")
})

kaggle_fabricado <- function() {
  data.frame(
    player_id = paste0("PLR", 1:8),
    skill = c(1, 2, 3, 4, 5, 6, 7, 8),
    avg_buyin = c(2, 4.99, 5, 24.99, 25, 100, 3, 30),
    realized_roi = c(-100, -20, 0, 15, 40, -5, NA, 10),
    went_broke = c(1, 0, 0, 0, 0, 0, 1, 0),
    profitable = c(0, 0, 0, 1, 1, 0, 0, 1)
  )
}

test_that("estratificar_buyin usa as faixas do plano (limite inferior fechado)", {
  expect_equal(
    estratificar_buyin(c(0, 4.99, 5, 24.99, 25, 1000)),
    c("micro", "micro", "low", "low", "mid_high", "mid_high")
  )
})

test_that("carregar_populacao_kaggle padroniza colunas e estratifica", {
  caminho <- escrever_csv(kaggle_fabricado())
  pop <- carregar_populacao_kaggle(caminho)
  expect_equal(nrow(pop), 7) # linha com ROI ausente e descartada
  expect_equal(pop$roi, c(-100, -20, 0, 15, 40, -5, 10))
  expect_equal(pop$lucrativo, as.integer(pop$roi > 0))
  expect_equal(pop$estrato, c("micro", "micro", "low", "low", "mid_high", "mid_high", "mid_high"))

  pop_skill <- carregar_populacao_kaggle(caminho, estratificar_por = "skill")
  expect_equal(length(unique(pop_skill$estrato)), 4)
  expect_false("estrato" %in% names(carregar_populacao_kaggle(caminho, "nenhum")))

  incompleto <- escrever_csv(data.frame(player_id = "a", realized_roi = 1))
  expect_error(carregar_populacao_kaggle(incompleto), "faltando")
})

listagem_fabricada <- function(torneio_id = c("0012", "13", "14", "15")) {
  data.frame(
    bloco_id = c(30, 30, 34, 34), torneio_id = torneio_id, nome = "MTT",
    inicio_fonte = "2026-10-13 10:15", fuso_fonte = "America/Sao_Paulo",
    inicio_brasilia = "2026-10-13 10:15", tipo = c("mtt", "mtt", "freeroll", "mtt"),
    buy_in = c(5.50, 0.55, 0, 109), n_entradas_fonte = c(100, 50, 30, 20), status = "concluido",
    motivo_exclusao = c(NA, "buyin_abaixo_1", "freeroll", NA), fonte = "sharkscope",
    data_listagem = "2026-10-20", observacao = NA
  )
}

test_that("carregar_listagem marca os elegiveis e rejeita torneio duplicado", {
  listagem <- carregar_listagem(escrever_csv(listagem_fabricada()))
  expect_equal(listagem$elegivel, c(TRUE, FALSE, FALSE, TRUE))
  expect_equal(listagem$torneio_id[1], "0012") # ID lido como texto, sem perder zeros
  duplicada <- escrever_csv(listagem_fabricada(c("1", "1", "2", "3")))
  expect_error(carregar_listagem(duplicada), "duplicado")
})

test_that("montar_moldura fica com os elegiveis e classifica o estrato", {
  moldura <- montar_moldura(carregar_listagem(escrever_csv(listagem_fabricada())))
  expect_equal(moldura$torneio_id, c("0012", "15"))
  expect_equal(moldura$bloco_id, c(30L, 34L))
  expect_equal(moldura$estrato, c("low", "mid_high"))
  expect_equal(moldura$n_inscritos, c(100L, 20L)) # M_k = entradas da fonte
})

top10_fabricado <- function(posicao = 1:10) {
  data.frame(
    bloco_id = 30, torneio_id = "0040", posicao = posicao, nickname = paste0("p", posicao),
    data_anotacao = "2026-10-20"
  )
}

test_that("carregar_top10 tipa as colunas e rejeita posicao invalida", {
  top10 <- carregar_top10(escrever_csv(top10_fabricado()))
  expect_equal(top10$torneio_id[1], "0040")
  expect_type(top10$posicao, "integer")
  expect_error(carregar_top10(escrever_csv(top10_fabricado(c(1:9, 11)))), "fora de 1 a 10")
  expect_error(carregar_top10(escrever_csv(top10_fabricado(c(1:9, 9)))), "repetida")
})

test_that("carregar_coleta cria as variaveis lucrativo e lucrativo_estrito", {
  caminho <- escrever_csv(data.frame(
    estrato = "micro", torneio_id = "1", n_inscritos = 10, nickname = c("a", "b", "c"),
    respondeu = c(TRUE, FALSE, TRUE), roi = c(15, -100, 2), lucro = c(3, -20, -50)
  ))
  coleta <- carregar_coleta(caminho)
  expect_equal(coleta$lucrativo, c(1L, 0L, 1L))
  expect_equal(coleta$lucrativo_estrito, c(1L, 0L, 0L)) # ROI > 0 com lucro < 0
  expect_type(coleta$respondeu, "logical")
})
