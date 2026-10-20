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

test_that("gera os B = 120 blocos de 2 h do periodo", {
  blocos <- gerar_blocos("2026-10-11", n_dias = 10, horas_por_bloco = 2)
  expect_equal(nrow(blocos), 120)
  expect_equal(blocos$inicio[1], "2026-10-11 00:00")
  expect_equal(blocos$fim[120], "2026-10-21 00:00")
  expect_equal(blocos$inicio_utc[1], "2026-10-11T03:00:00Z") # Brasilia fica 3 h atras de UTC
  expect_equal(blocos$dia_semana[1], 7) # 11/10/2026 e domingo
  expect_equal(sum(blocos$fim_de_semana), 3 * 12) # 11/10 e 17-18/10
  expect_error(gerar_blocos("2026-10-11", 10, horas_por_bloco = 5), "dividir 24")
})

test_that("sorteia b blocos distintos, de forma reprodutivel", {
  blocos <- gerar_blocos("2026-10-11", 10)
  a <- sortear_blocos(blocos, 6, seed = 164363)
  expect_identical(a, sortear_blocos(blocos, 6, seed = 164363))
  expect_equal(a$bloco_id, c(30, 34, 63, 100, 105, 109)) # sorteio oficial da Fase 0
  expect_equal(nrow(a), 6)
  expect_false(anyDuplicated(a$bloco_id) > 0)
  expect_true(all(diff(a$bloco_id) > 0))
  expect_setequal(a$ordem_sorteio, 1:6)
  expect_equal(unique(a$B), 120)
  expect_error(sortear_blocos(blocos, 1, seed = 1), "ao menos 2")
  expect_error(sortear_blocos(blocos[1:3, ], 4, seed = 1), "so 3 blocos")
})

test_that("sorteio nao altera o estado global do RNG", {
  set.seed(99)
  antes <- .Random.seed
  sortear_torneios(moldura_exemplo(), 2, seed = 1)
  expect_identical(.Random.seed, antes)
})
