# Testes de `R/sorteio.R`.

# Dois blocos; no bloco 34, o estrato mid_high tem so 1 torneio.
moldura_exemplo <- function() {
  data.frame(
    bloco_id = rep(c(30, 34), times = c(20, 9)),
    estrato = c(
      rep(c("micro", "low", "mid_high"), times = c(10, 6, 4)),
      rep(c("micro", "low", "mid_high"), times = c(5, 3, 1))
    ),
    torneio_id = paste0("t", 1:29),
    buy_in = 1,
    n_inscritos = NA_integer_,
    stringsAsFactors = FALSE
  )
}

test_that("sorteia n_jh torneios por (bloco, estrato), de forma reprodutivel", {
  a <- sortear_torneios(moldura_exemplo(), 3, seed = 1)
  expect_identical(a, sortear_torneios(moldura_exemplo(), 3, seed = 1))
  no_30 <- a[a$bloco_id == 30, ]
  expect_equal(as.numeric(table(no_30$estrato)[c("micro", "low", "mid_high")]), c(3, 3, 3))
  expect_equal(unique(no_30$N_jh[no_30$estrato == "micro"]), 10)
  expect_false(anyDuplicated(a$torneio_id) > 0)
})

test_that("celula com N_jh <= n_jh entra inteira (censo)", {
  a <- sortear_torneios(moldura_exemplo(), 3, seed = 1)
  celula <- a[a$bloco_id == 34 & a$estrato == "mid_high", ]
  expect_equal(nrow(celula), 1)
  expect_equal(celula$N_jh, 1)
  expect_equal(celula$n_jh, 1)
})

test_that("sorteio de um bloco nao muda quando outros blocos entram depois", {
  completo <- sortear_torneios(moldura_exemplo(), 2, seed = 7)
  so_30 <- sortear_torneios(moldura_exemplo()[1:20, ], 2, seed = 7)
  expect_equal(so_30$torneio_id, completo$torneio_id[completo$bloco_id == 30])
})

torneios_exemplo <- function() {
  data.frame(
    bloco_id = 30, estrato = "micro", torneio_id = c("t1", "t2", "t3"),
    n_inscritos = c(114L, 10L, 4L), stringsAsFactors = FALSE
  )
}

test_that("sorteio de jogadores de um torneio nao depende dos outros torneios", {
  completo <- sortear_jogadores(torneios_exemplo(), 2, 3, seed = 7)
  so_t1 <- sortear_jogadores(torneios_exemplo()[1, ], 2, 3, seed = 7)
  expect_equal(so_t1$posicao, completo$posicao[completo$torneio_id == "t1"])
})

test_that("aumentar a reserva so acrescenta posicoes ao fim da ordem", {
  curta <- sortear_jogadores(torneios_exemplo()[1, ], 2, 3, seed = 7)
  longa <- sortear_jogadores(torneios_exemplo()[1, ], 2, 8, seed = 7)
  expect_equal(longa$posicao[1:5], curta$posicao)
})

test_that("aceita n_h nomeado e exige minimo de 2", {
  a <- sortear_torneios(moldura_exemplo(), c(micro = 4, low = 2, mid_high = 2), seed = 2)
  expect_equal(sum(a$estrato == "micro" & a$bloco_id == 30), 4)
  expect_error(sortear_torneios(moldura_exemplo(), 1, seed = 2), "ao menos 2")
})

test_that("sorteia posicoes distintas de 1 a M_k, com titulares e reserva", {
  s <- sortear_jogadores(torneios_exemplo(), m_por_torneio = 2, n_reserva = 3, seed = 3)
  expect_equal(as.numeric(table(s$torneio_id)), c(5, 5, 4)) # t3 tem so 4 entradas
  expect_equal(sum(s$tipo == "titular"), 6)
  for (k in c("t1", "t2", "t3")) {
    no_k <- s[s$torneio_id == k, ]
    expect_false(anyDuplicated(no_k$posicao) > 0)
    expect_true(all(no_k$posicao >= 1 & no_k$posicao <= no_k$n_inscritos))
    expect_equal(no_k$ordem, seq_len(nrow(no_k)))
  }
  expect_equal(unique(s$bloco_id), 30) # colunas do torneio sao mantidas
  expect_error(sortear_jogadores(torneios_exemplo(), 1, 0, seed = 3), "ao menos 2")
})

test_that("gera os B = 38 blocos de 2 h do periodo", {
  blocos <- gerar_blocos("2026-10-17 20:00", "2026-10-21 00:00", horas_por_bloco = 2)
  expect_equal(nrow(blocos), 38)
  expect_equal(blocos$inicio[1], "2026-10-17 20:00")
  expect_equal(blocos$fim[38], "2026-10-21 00:00")
  expect_equal(blocos$inicio_utc[1], "2026-10-17T23:00:00Z") # Brasilia fica 3 h atras de UTC
  expect_equal(blocos$dia_semana[1], 6) # 17/10/2026 e sabado
  expect_equal(sum(blocos$fim_de_semana), 2 + 12) # 17/10 a partir das 20:00 e 18/10
  expect_equal(nrow(gerar_blocos("2026-10-11", "2026-10-21")), 120)
  expect_error(gerar_blocos("2026-10-11", "2026-10-12", horas_por_bloco = 5), "dividir 24")
  expect_error(gerar_blocos("2026-10-17 18:24", "2026-10-21 00:00"), "multipla")
})

test_that("sorteia b blocos distintos, de forma reprodutivel", {
  blocos <- gerar_blocos("2026-10-17 20:00", "2026-10-21 00:00")
  a <- sortear_blocos(blocos, 6, seed = 164363)
  expect_identical(a, sortear_blocos(blocos, 6, seed = 164363))
  expect_equal(a$bloco_id, c(5, 8, 24, 30, 34, 36)) # sorteio oficial da Fase 0
  expect_equal(nrow(a), 6)
  expect_false(anyDuplicated(a$bloco_id) > 0)
  expect_true(all(diff(a$bloco_id) > 0))
  expect_setequal(a$ordem_sorteio, 1:6)
  expect_equal(unique(a$B), 38)
  expect_error(sortear_blocos(blocos, 1, seed = 1), "ao menos 2")
  expect_error(sortear_blocos(blocos[1:3, ], 4, seed = 1), "so 3 blocos")
})

test_that("sorteio nao altera o estado global do RNG", {
  set.seed(99)
  antes <- .Random.seed
  sortear_torneios(moldura_exemplo(), 2, seed = 1)
  expect_identical(.Random.seed, antes)
})
