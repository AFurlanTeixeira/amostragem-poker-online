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

test_that("carregar_moldura rejeita torneio duplicado", {
  caminho <- escrever_csv(data.frame(
    estrato = "micro", torneio_id = c("1", "1"), buy_in = 1, n_inscritos = 10
  ))
  expect_error(carregar_moldura(caminho), "duplicado")
})

test_that("carregar_coleta cria a variavel lucrativo", {
  caminho <- escrever_csv(data.frame(
    estrato = "micro", torneio_id = "1", n_inscritos = 10, nickname = c("a", "b"),
    respondeu = c(TRUE, FALSE), roi = c(15, -100), lucro = c(3, -20)
  ))
  coleta <- carregar_coleta(caminho)
  expect_equal(coleta$lucrativo, c(1L, 0L))
  expect_type(coleta$respondeu, "logical")
})
