# Testes de `R/sorteio.R`.

moldura_exemplo <- function() {
  data.frame(
    estrato = rep(c("micro", "low", "mid_high"), times = c(10, 6, 4)),
    torneio_id = paste0("t", 1:20),
    buy_in = 1,
    n_inscritos = 50,
    stringsAsFactors = FALSE
  )
}

test_that("sorteia n_h torneios por estrato, de forma reprodutivel", {
  a <- sortear_torneios(moldura_exemplo(), 3, seed = 1)
  b <- sortear_torneios(moldura_exemplo(), 3, seed = 1)
  expect_identical(a, b)
  expect_equal(as.numeric(table(a$estrato)[c("micro", "low", "mid_high")]), c(3, 3, 3))
  expect_equal(unique(a$N_h[a$estrato == "micro"]), 10)
  expect_false(anyDuplicated(a$torneio_id) > 0)
})

test_that("aceita n_h nomeado e exige minimo de 2", {
  a <- sortear_torneios(moldura_exemplo(), c(micro = 4, low = 2, mid_high = 2), seed = 2)
  expect_equal(sum(a$estrato == "micro"), 4)
  expect_error(sortear_torneios(moldura_exemplo(), 1, seed = 2), "ao menos 2")
  expect_error(sortear_torneios(moldura_exemplo(), 5, seed = 2), "so 4 torneios")
})

test_that("sorteia titulares e reserva sem repetir jogador", {
  inscritos <- data.frame(
    torneio_id = rep(c("t1", "t2"), each = 10),
    nickname = paste0("p", 1:20),
    stringsAsFactors = FALSE
  )
  s <- sortear_jogadores(inscritos, m_por_torneio = 4, n_reserva = 3, seed = 3)
  expect_equal(sum(s$tipo == "titular"), 8)
  expect_equal(sum(s$tipo == "reserva"), 6)
  expect_false(anyDuplicated(s$nickname) > 0)
  expect_error(sortear_jogadores(inscritos, 1, 0, seed = 3), "ao menos 2")
})

test_that("sorteio nao altera o estado global do RNG", {
  set.seed(99)
  antes <- .Random.seed
  sortear_torneios(moldura_exemplo(), 2, seed = 1)
  expect_identical(.Random.seed, antes)
})
