# Testes de `R/estimadores_aas.R`.
#
# Exemplos 1 e 2 do Thompson (2012), §11.2-11.3 (p. 144-146): tres estratos
# com N_h = (20, 9, 12), n_h = (5, 3, 4), ybar_h = (1.6, 2.8, 0.6),
# s2_h = (3.3, 4.0, 2.2).

test_that("estratificada reproduz o Exemplo 1 do Thompson", {
  res <- combinar_estratos(c(20, 9, 12), c(5, 3, 4), c(1.6, 2.8, 0.6), c(3.3, 4.0, 2.2))
  expect_equal(res$estimativa, 64.4 / 41)
  expect_equal(res$variancia, 322.8 / 41^2)
  expect_equal(res$gl, 7.82, tolerance = 1e-3)
  # IC 95% do livro: (0,56; 2,58), com t de 8 gl; aqui o gl e fracionario.
  expect_equal(res$li, 0.56, tolerance = 0.02)
  expect_equal(res$ls, 2.58, tolerance = 0.02)
})

test_that("AAS aplica a FCPF", {
  y <- c(2, 4, 6, 8)
  res <- estimar_media_aas(y, N = 8)
  expect_equal(res$estimativa, 5)
  expect_equal(res$variancia, (1 - 4 / 8) * var(y) / 4)
  expect_equal(estimar_media_aas(y, N = 4)$variancia, 0)
})

test_that("IC logit fica em (0, 1) e e simetrico na escala logit", {
  perto_de_1 <- montar_resultado(0.854, 0.0729^2, gl = 3, nivel = 0.95)
  expect_gt(perto_de_1$ls, 1) # o Wald passa de 1
  ic <- ic_logit(perto_de_1)
  expect_true(ic[["li"]] > 0 && ic[["ls"]] < 1)
  expect_equal(mean(qlogis(ic)), qlogis(0.854))
  expect_equal(ic[["li"]], 0.476, tolerance = 1e-3) # conta a mao
  # Com p = 0,5 e EP pequeno, coincide com o Wald (p(1 - p) = 1/4).
  meio <- montar_resultado(0.5, 1e-6, gl = 30, nivel = 0.95)
  expect_equal(unname(ic_logit(meio)), c(meio$li, meio$ls), tolerance = 1e-6)
  expect_true(all(is.na(ic_logit(list(estimativa = 1, erro_padrao = 0, gl = 3)))))
})

test_that("estratificada a partir dos dados equivale a combinar_estratos", {
  y <- c(1, 3, 5, 10, 12, 14)
  estrato <- rep(c("a", "b"), each = 3)
  res <- estimar_media_estratificada(y, estrato, c(a = 30, b = 10))
  esperado <- combinar_estratos(c(30, 10), c(3, 3), c(3, 12), c(4, 4))
  expect_equal(res$estimativa, esperado$estimativa)
  expect_equal(res$variancia, esperado$variancia)
})
