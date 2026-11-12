# Testes de `R/simulacao_kaggle.R`.
#
# Populacao sintetica (nao e o dataset do Kaggle): dois estratos com medias
# bem diferentes, para a estratificacao ter ganho claro.

populacao_sintetica <- function() {
  set.seed(10)
  data.frame(
    roi = c(rnorm(600, mean = -20, sd = 10), rnorm(400, mean = 40, sd = 10)),
    estrato = rep(c("a", "b"), times = c(600, 400)),
    stringsAsFactors = FALSE
  )
}

test_that("alocacao proporcional respeita o minimo por estrato", {
  expect_equal(alocacao_proporcional(c(a = 900, b = 100), 20), c(a = 18L, b = 2L))
  # O minimo no estrato pequeno sai do estrato grande: a soma continua n.
  expect_equal(alocacao_proporcional(c(a = 990, b = 10), 20), c(a = 18L, b = 2L))
})

test_that("alocacao proporcional soma n nos tamanhos usados no projeto", {
  buyin <- c(low = 14652, micro = 1060, mid_high = 29288)
  skill <- c(q1 = 11250, q2 = 11250, q3 = 11250, q4 = 11250)
  for (n in c(60, 67, 120)) {
    expect_equal(sum(alocacao_proporcional(buyin, n)), n)
    expect_equal(sum(alocacao_proporcional(skill, n)), n)
  }
})

test_that("alocacao rejeita n impossivel em vez de entrar em laco", {
  N_h <- c(a = 10, b = 10)
  expect_error(alocacao_proporcional(N_h, 3), "fora do intervalo")
  expect_error(alocacao_proporcional(N_h, 21), "fora do intervalo")
  expect_error(alocacao_neyman(N_h, c(a = 1, b = 2), 3), "fora do intervalo")
  expect_error(alocacao_proporcional(c(a = 10, b = 1), 6), "N_h >= 2")
})

test_that("alocacao de Neyman e proporcional a N_h S_h", {
  # N_h S_h = 6000 e 12000: 1/3 e 2/3 de 36.
  expect_equal(alocacao_neyman(c(a = 600, b = 400), c(a = 10, b = 30), 36), c(a = 12L, b = 24L))
  # Estrato sem variacao fica com o minimo de 2.
  expect_equal(alocacao_neyman(c(a = 500, b = 500), c(a = 0, b = 5), 20), c(a = 2L, b = 18L))
  # Arredondamento nao muda o n total (maiores restos): 39,4 / 3,0 / 78,6 -> 120.
  N_h <- c(low = 14652, micro = 1060, mid_high = 29288)
  S_h <- c(low = 45.631, micro = 43.125, mid_high = 46.227)
  expect_equal(sum(alocacao_neyman(N_h, S_h, 120)), 120)
})

test_that("planos sao aproximadamente nao viesados e estratificar reduz a variancia", {
  pop <- populacao_sintetica()
  sims <- simular_planos(pop, "roi", n = 50, n_rep = 400, seed = 42)
  resumo <- resumir_simulacao(sims, parametro = mean(pop$roi))

  expect_setequal(
    resumo$plano, c("AAS", "AAS estratificada (proporcional)", "AAS estratificada (Neyman)")
  )
  expect_true(all(abs(resumo$vies) < 1.5))
  expect_true(all(resumo$cobertura > 0.88))
  expect_lt(resumo$epa_empirico[resumo$plano == "AAS estratificada (proporcional)"], 0.5)
})

test_that("Neyman ganha da proporcional quando os DPs dos estratos diferem", {
  set.seed(11)
  pop <- data.frame(
    roi = c(rnorm(500, mean = 0, sd = 2), rnorm(500, mean = 10, sd = 40)),
    estrato = rep(c("a", "b"), each = 500),
    stringsAsFactors = FALSE
  )
  sims <- simular_planos(pop, "roi", n = 40, n_rep = 400, seed = 3)
  resumo <- resumir_simulacao(sims, parametro = mean(pop$roi))
  epa <- stats::setNames(resumo$epa_empirico, resumo$plano)
  expect_lt(epa[["AAS estratificada (Neyman)"]], epa[["AAS estratificada (proporcional)"]])
})

test_that("Neyman nao muda as replicas de AAS e da proporcional", {
  pop <- populacao_sintetica()
  sims <- simular_planos(pop, "roi", n = 30, n_rep = 5, seed = 7)
  # Refaz o fluxo principal sem Neyman: em cada replica, a AAS e depois a
  # proporcional (estratos em ordem, 18 de "a" e 12 de "b"). Se o sorteio de
  # Neyman consumisse esse fluxo, as replicas 2 a 5 nao bateriam.
  idx <- split(seq_len(nrow(pop)), pop$estrato)
  esperado <- withr_seed(7, {
    lapply(1:5, function(r) {
      aas <- mean(pop$roi[sample.int(nrow(pop), 30)])
      a <- idx$a[sample.int(length(idx$a), 18)]
      b <- idx$b[sample.int(length(idx$b), 12)]
      c(aas = aas, prop = 0.6 * mean(pop$roi[a]) + 0.4 * mean(pop$roi[b]))
    })
  })
  esperado <- do.call(rbind, esperado)
  expect_equal(sims$estimativa[sims$plano == "AAS"], unname(esperado[, "aas"]))
  expect_equal(
    sims$estimativa[sims$plano == "AAS estratificada (proporcional)"],
    unname(esperado[, "prop"])
  )
})

test_that("semente invalida para com erro claro", {
  pop <- populacao_sintetica()
  expect_error(simular_planos(pop, "roi", 30, 2, seed = NA_integer_), "Semente invalida")
  expect_error(withr_seed(NULL, 1), "Semente invalida")
})

test_that("simulacao e reprodutivel pela semente", {
  pop <- populacao_sintetica()
  a <- simular_planos(pop, "roi", n = 30, n_rep = 5, seed = 7)
  b <- simular_planos(pop, "roi", n = 30, n_rep = 5, seed = 7)
  expect_identical(a, b)
})
