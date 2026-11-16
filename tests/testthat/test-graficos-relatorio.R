estimativas_teste <- function() {
  data.frame(
    parametro = c("ROI médio (%)", "ROI > 0", "ROI > 0 e lucro > 0"),
    escala = c("roi", "proporcao", "proporcao"),
    estimativa = c(17.5, 0.85, 0.72),
    li = c(-0.04, 0.48, 0.13), ls = c(35, 0.97, 0.98),
    li_jk1 = c(0.9, 0.23, 0.03), ls_jk1 = c(34, 0.99, 0.99)
  )
}

mc_teste <- function() {
  data.frame(
    variavel = rep(c("roi", "lucrativo"), each = 3),
    rotulo = rep(c("ROI médio (%)", "Lucrativos"), each = 3),
    b = rep(c(4, 6, 12), 2),
    cobertura_wald = c(0.933, 0.924, 0.920, 0.898, 0.880, 0.871),
    cobertura_logit = c(NA, NA, NA, 0.946, 0.931, 0.922),
    cobertura_jk1 = c(0.940, 0.931, 0.929, 0.908, 0.902, 0.894)
  )
}

test_that("graficos do relatorio desenham sem erro", {
  arquivo <- tempfile(fileext = ".png")
  grDevices::png(arquivo, width = 900, height = 400)
  expect_silent(grafico_estimativas_ic(estimativas_teste()))
  expect_silent(grafico_cobertura_b(mc_teste()))
  nr <- data.frame(estrato = c("low", "micro", "mid_high"), taxa_nao_resposta = c(0.57, 0.63, 0.4))
  expect_silent(grafico_nao_resposta_estratos(nr, total = 0.55))
  grDevices::dev.off()
  expect_true(file.exists(arquivo))
})

test_that("graficos do relatorio recusam colunas faltando", {
  expect_error(grafico_estimativas_ic(estimativas_teste()[, -1]))
  expect_error(grafico_cobertura_b(mc_teste()[, c("variavel", "b")]))
  expect_error(grafico_nao_resposta_estratos(data.frame(estrato = "micro"), total = 0.5))
})
