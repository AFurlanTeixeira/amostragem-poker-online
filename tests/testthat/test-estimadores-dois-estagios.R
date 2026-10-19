# Testes de `R/estimadores_dois_estagios.R`.
#
# Valores esperados conferidos com os Exemplos 1 e 2 do Thompson (2012),
# §13.1 (p. 174-176): N = 100 torneios, n = 3 sorteados, M = (24, 20, 15),
# m = 2 jogadores por torneio, populacao total M0 = 2500.

coleta_thompson <- function() {
  data.frame(
    estrato = "A",
    torneio_id = rep(c("t1", "t2", "t3"), each = 2),
    n_inscritos = rep(c(24, 20, 15), each = 2),
    nickname = paste0("j", 1:6),
    respondeu = TRUE,
    roi = c(8, 12, 0, 0, 1, 3),
    lucro = 0,
    stringsAsFactors = FALSE
  )
}

moldura_thompson <- function() {
  # 3 torneios sorteados + 97 outros, somando M0 = 2500 inscritos.
  data.frame(
    estrato = "A",
    torneio_id = c("t1", "t2", "t3", paste0("x", 1:97)),
    buy_in = 1,
    n_inscritos = c(24, 20, 15, rep(25, 96), 41),
    stringsAsFactors = FALSE
  )
}

test_that("termos de variancia batem com o Exemplo 1 do Thompson", {
  expect_equal(variancia_entre(100, c(240, 0, 30)), 55290000)
  expect_equal(variancia_dentro(100, c(24, 20, 15), c(2, 2, 2), c(8, 0, 2)), 76900)
})

test_that("estimador nao viesado reproduz tau = 9000 e var = 55.366.900", {
  res <- estimar_media_dois_estagios(coleta_thompson(), moldura_thompson(), metodo = "nao_viesado")
  expect_equal(res$M0, 2500)
  expect_equal(res$estimativa * 2500, 9000)
  expect_equal(res$variancia * 2500^2, 55366900)
  expect_equal(res$gl, 2)
})

test_that("estimador razao reproduz o Exemplo 2 do Thompson", {
  res <- estimar_media_dois_estagios(coleta_thompson(), moldura_thompson(), metodo = "razao")
  expect_equal(res$estimativa * 2500, 11441, tolerance = 1e-4)
  # Thompson arredonda r = 4,58 e obtem 43.426.788.
  expect_equal(res$variancia * 2500^2, 43426788, tolerance = 5e-3)
})

test_that("auto escolhe razao quando falta n_inscritos na moldura", {
  moldura <- moldura_thompson()
  moldura$n_inscritos[50] <- NA
  res <- estimar_media_dois_estagios(coleta_thompson(), moldura)
  expect_equal(res$metodo, "razao")
  expect_error(estimar_media_dois_estagios(coleta_thompson(), moldura, metodo = "nao_viesado"))
})

test_that("perfis privados sao excluidos e minimos sao exigidos", {
  coleta <- coleta_thompson()
  coleta$respondeu[1] <- FALSE
  expect_error(estimar_media_dois_estagios(coleta, moldura_thompson()), "menos de 2 respondentes")
  expect_equal(taxa_nao_resposta(coleta)$taxa_nao_resposta, 1 / 6)
})

test_that("estratos se somam e EPA e coerente com rho_int", {
  c1 <- coleta_thompson()
  c2 <- coleta_thompson()
  c2$estrato <- "B"
  c2$torneio_id <- paste0(c2$torneio_id, "b")
  m1 <- moldura_thompson()
  m2 <- moldura_thompson()
  m2$estrato <- "B"
  m2$torneio_id <- paste0(m2$torneio_id, "b")

  res <- estimar_media_dois_estagios(rbind(c1, c2), rbind(m1, m2), metodo = "nao_viesado")
  expect_equal(res$estimativa, 3.6)
  expect_equal(res$variancia * 5000^2, 2 * 55366900)
  expect_equal(res$gl, 4)

  epa <- calcular_epa(res, rbind(c1, c2), rbind(m1, m2))
  expect_gt(epa$epa, 0)
  expect_equal(epa$rho_int, (epa$epa - 1) / (epa$m_medio - 1))
})

test_that("proporcao de lucrativos usa as mesmas formulas", {
  coleta <- coleta_thompson()
  coleta$lucrativo <- as.integer(coleta$roi > 0)
  res <- estimar_media_dois_estagios(coleta, moldura_thompson(), variavel = "lucrativo")
  # yhat = (24, 0, 15) -> tau = 100/3 * 39 = 1300 -> P = 0,52
  expect_equal(res$estimativa, 0.52)
})
