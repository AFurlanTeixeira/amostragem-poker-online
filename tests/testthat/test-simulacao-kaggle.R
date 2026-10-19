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
  expect_equal(alocacao_proporcional(c(a = 990, b = 10), 20), c(a = 20L, b = 2L))
})

test_that("planos sao aproximadamente nao viesados e estratificar reduz a variancia", {
  pop <- populacao_sintetica()
  sims <- simular_planos(pop, "roi", n = 50, n_rep = 400, seed = 42)
  resumo <- resumir_simulacao(sims, parametro = mean(pop$roi))

  expect_setequal(resumo$plano, c("AAS", "AAS estratificada"))
  expect_true(all(abs(resumo$vies) < 1.5))
  expect_true(all(resumo$cobertura > 0.88))
  expect_lt(resumo$epa_empirico[resumo$plano == "AAS estratificada"], 0.5)
})

test_that("simulacao e reprodutivel pela semente", {
  pop <- populacao_sintetica()
  a <- simular_planos(pop, "roi", n = 30, n_rep = 5, seed = 7)
  b <- simular_planos(pop, "roi", n = 30, n_rep = 5, seed = 7)
  expect_identical(a, b)
})
