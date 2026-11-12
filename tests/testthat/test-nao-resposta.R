# Testes de `R/nao_resposta.R`.
#
# Coleta fabricada: 2 blocos, 1 estrato, 3 torneios por bloco com M_k = 20.
# Em cada torneio, 4 posicoes consultadas: 2 na metade de cima (2 e 5), que
# respondem com lucrativo = 1, e 2 na metade de baixo (15 e 18), das quais so
# a 15 responde, com lucrativo = 0.

coleta_posicao <- function() {
  um_bloco <- function(j) {
    data.frame(
      bloco_id = j,
      estrato = "A",
      torneio_id = rep(paste0("t", 1:3, "_", j), each = 4),
      n_inscritos = 20,
      posicao = rep(c(2, 5, 15, 18), 3),
      respondeu = rep(c(TRUE, TRUE, TRUE, FALSE), 3),
      roi = rep(c(10, 20, -50, NA), 3),
      lucro = rep(c(1, 1, -1, NA), 3),
      lucrativo = rep(c(1, 1, 0, NA), 3),
      lucrativo_estrito = rep(c(1, 1, 0, NA), 3),
      n_jogos_dia = rep(c(2, 2, 2, NA), 3),
      stringsAsFactors = FALSE
    )
  }
  rbind(um_bloco(1), um_bloco(2))
}

moldura_posicao <- function() {
  data.frame(
    bloco_id = rep(1:2, each = 10),
    estrato = "A",
    torneio_id = c(paste0("t", 1:10, "_1"), paste0("t", 1:10, "_2")),
    buy_in = 1,
    n_inscritos = 20,
    stringsAsFactors = FALSE
  )
}

test_that("limites de pior caso tratam os nao respondentes como 0 e como 1", {
  lim <- limites_pior_caso(coleta_posicao(), moldura_posicao(), B = 10, variavel = "lucrativo")
  # Por torneio: 2 de 4 (todos os nao respondentes com 0) ou 3 de 4 (com 1).
  expect_equal(lim$inferior, 0.5)
  expect_equal(lim$superior, 0.75)
  expect_equal(lim$observada, 2 / 3)
  expect_equal(lim$taxa_resposta, 0.75)
})

test_that("sem nao resposta os limites coincidem com a estimativa", {
  co <- coleta_posicao()
  co <- co[co$respondeu, ]
  lim <- limites_pior_caso(co, moldura_posicao(), B = 10, variavel = "lucrativo")
  expect_equal(lim$inferior, lim$superior)
  expect_equal(lim$inferior, lim$observada)
})

test_that("ajuste por posicao repoe o peso da metade que responde menos", {
  aj <- ajustar_por_posicao(
    coleta_posicao(), moldura_posicao(), B = 10, variavel = "lucrativo", unidade = "inscricao"
  )
  # Celula: taxa 9/12; metade de cima 1, de baixo 1/2. Fatores 0,75 e 1,5:
  # (2 x 0,75 x 1 + 1,5 x 0) / (2 x 0,75 + 1,5) = 0,5.
  expect_equal(aj$sem_ajuste, 2 / 3)
  expect_equal(aj$ajustada, 0.5)
  expect_equal(aj$celulas_colapsadas, 0)
})

test_that("taxas iguais entre as classes nao mudam a estimativa", {
  co <- coleta_posicao()
  co$respondeu[co$posicao == 5] <- FALSE # cada metade responde 1 de 2 (2 e 15)
  co$lucrativo[co$posicao == 5] <- NA
  aj <- ajustar_por_posicao(co, moldura_posicao(), B = 10, variavel = "lucrativo")
  expect_equal(aj$ajustada, aj$sem_ajuste)
})

test_that("classe sem respondente na celula e colapsada", {
  co <- coleta_posicao()
  co$respondeu[co$bloco_id == 1 & co$posicao == 15] <- FALSE
  co$respondeu[co$bloco_id == 1 & co$posicao == 2] <- TRUE
  co <- rbind(co, transform(co[co$bloco_id == 1 & co$posicao == 2, ], posicao = 3))
  aj <- ajustar_por_posicao(co, moldura_posicao(), B = 10, variavel = "lucrativo")
  expect_equal(aj$celulas_colapsadas, 1)
  expect_true(is.finite(aj$ajustada))
})
