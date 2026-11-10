# Testes de `R/exploracao_estratos.R`, com dados pequenos calculados a mao.

# Dois blocos, dois estratos, dois torneios por celula, dois jogadores por
# torneio. ROI = 10 * estrato_low + 2 * torneio + jogador, para as contas da
# decomposicao sairem inteiras.
coleta_aed <- function() {
  grade <- expand.grid(
    jogador = 1:2, torneio = 1:2, estrato = c("micro", "low"), bloco_id = c(1L, 2L),
    stringsAsFactors = FALSE
  )
  data.frame(
    bloco_id = grade$bloco_id,
    estrato = grade$estrato,
    torneio_id = paste(grade$bloco_id, grade$estrato, grade$torneio, sep = "_"),
    n_inscritos = 20,
    nickname = paste0("j", seq_len(nrow(grade))),
    respondeu = TRUE,
    roi = 10 * (grade$estrato == "low") + 2 * grade$torneio + grade$jogador,
    lucro = 1,
    n_jogos_dia = 1,
    lucrativo = 1L,
    stringsAsFactors = FALSE
  )
}

moldura_aed <- function() {
  data.frame(
    bloco_id = rep(c(1L, 2L), each = 7),
    estrato = rep(c("micro", "micro", "micro", "low", "low", "low", "low"), 2),
    torneio_id = c(
      "1_micro_1", "1_micro_2", "1_micro_x", "1_low_1", "1_low_2", "1_low_x", "1_low_y",
      "2_micro_1", "2_micro_2", "2_micro_x", "2_low_1", "2_low_2", "2_low_x", "2_low_y"
    ),
    buy_in = rep(c(2, 2, 3, 10, 10, 20, 11), 2),
    n_inscritos = rep(c(20, 20, 50, 20, 20, 30, 10), 2),
    stringsAsFactors = FALSE
  )
}

test_that("resumo da moldura conta torneios e inscricoes por estrato", {
  res <- resumir_moldura_estratos(moldura_aed())
  expect_equal(res$estrato, c("micro", "low"))
  expect_equal(res$torneios, c(6, 8))
  expect_equal(res$inscricoes, c(180, 160))
  expect_equal(res$buyin_mediana, c(2, 10.5))
  expect_equal(sum(res$pct_inscricoes), 100)
})

test_that("tabela de celulas traz N_jh, n_jh e respondentes", {
  col <- coleta_aed()
  col$respondeu[1] <- FALSE
  cel <- tabela_celulas(moldura_aed(), col)
  expect_equal(nrow(cel), 4)
  expect_equal(cel$estrato, c("micro", "low", "micro", "low"))
  expect_equal(cel$N_jh, c(3, 4, 3, 4))
  expect_equal(cel$n_jh, c(2, 2, 2, 2))
  expect_equal(cel$respondentes, c(3, 4, 4, 4))
})

test_that("resumo da variavel usa so respondentes e inclui o total", {
  col <- coleta_aed()
  col$respondeu[1] <- FALSE
  col$roi[1] <- 1e6 # nao respondente: nao pode entrar
  res <- resumir_variavel_estratos(col, "roi")
  expect_equal(res$estrato, c("micro", "low", "total"))
  expect_equal(res$n, c(7, 8, 15))
  expect_equal(res$maximo[1], 6)
  expect_equal(res$media[2], 14.5)
})

test_that("decomposicao soma a SQ total e isola cada nivel", {
  res <- decompor_variancia_estratos(coleta_aed(), "roi")
  y <- coleta_aed()$roi
  expect_equal(sum(res$sq), sum((y - mean(y))^2))
  expect_equal(sum(res$proporcao), 1)
  # Entre estratos: 16 jogadores, medias 4,5 e 14,5 em torno de 9,5.
  expect_equal(res$sq[1], 16 * 25)
  # Blocos iguais: nada entre blocos dentro do estrato.
  expect_equal(res$sq[2], 0)
  # Torneios: +-1 em torno da media da celula, 16 jogadores.
  expect_equal(res$sq[3], 16)
  # Dentro: +-0,5 em torno da media do torneio.
  expect_equal(res$sq[4], 16 * 0.25)
  expect_equal(res$gl, c(1, 2, 4, 8))
  expect_equal(res$qm, res$sq / res$gl)
})

test_that("dominio de cada estrato = estimador de tres estagios no subconjunto", {
  col <- coleta_aed()
  col$roi <- col$roi + col$bloco_id # blocos diferentes, para haver variancia
  mol <- moldura_aed()
  dom <- estimar_dominios_estratos(col, mol, B = 10, "roi", unidade = "inscricao")
  expect_equal(dom$estrato, c("micro", "low", "total"))
  micro <- estimar_media_tres_estagios(
    col[col$estrato == "micro", ], mol[mol$estrato == "micro", ], 10, "roi",
    unidade = "inscricao"
  )
  expect_equal(dom$estimativa[1], micro$estimativa)
  expect_equal(dom$erro_padrao[1], micro$erro_padrao)
  expect_equal(dom$gl, c(1, 1, 1))
  # N_hat e aditivo nos estratos.
  expect_equal(sum(dom$N_hat[1:2]), dom$N_hat[3])
  expect_equal(dom$pct_N_hat[3], 100)
})

test_that("dominio de uma proporcao usa o IC logit, dentro de (0, 1)", {
  col <- coleta_aed()
  col$lucrativo <- as.integer(col$roi > 4 + col$bloco_id)
  dom <- estimar_dominios_estratos(col, moldura_aed(), B = 10, "lucrativo", unidade = "inscricao")
  expect_true(all(dom$li > 0 & dom$ls < 1, na.rm = TRUE))
  res <- estimar_media_tres_estagios(col, moldura_aed(), 10, "lucrativo", unidade = "inscricao")
  expect_equal(c(dom$li[3], dom$ls[3]), unname(ic_logit(res)))
})

test_that("dominio falha se o estrato falta em um bloco com respondentes", {
  col <- coleta_aed()
  col <- col[!(col$estrato == "low" & col$bloco_id == 2), ]
  col$roi <- col$roi + col$bloco_id
  expect_error(
    estimar_dominios_estratos(col, moldura_aed(), B = 10, "roi", unidade = "inscricao"),
    "ausente"
  )
})

test_that("comparacao com o top 10 usa so os torneios consultados", {
  col <- coleta_aed()
  top10 <- data.frame(
    bloco_id = 1L,
    torneio_id = c(rep("1_micro_1", 4), rep("1_low_1", 2)),
    posicao = c(1:4, 1:2),
    nickname = "x",
    data_anotacao = "2026-10-20",
    respondeu = c(TRUE, TRUE, FALSE, NA, TRUE, TRUE),
    roi = c(5, -1, NA, NA, 3, 4),
    stringsAsFactors = FALSE
  )
  res <- comparar_top10_estratos(col, top10, moldura_aed())
  t10 <- res[res$grupo == "top10", ]
  expect_equal(t10$consultados, c(3, 2))
  expect_equal(t10$taxa_resposta, c(2 / 3, 1))
  expect_equal(t10$prop_lucrativos, c(0.5, 1))
  amo <- res[res$grupo == "amostra", ]
  expect_equal(amo$consultados, c(2, 2)) # so 1_micro_1 e 1_low_1
})

test_that("associacao com o buy-in devolve Kruskal-Wallis e Spearman", {
  res <- associar_buyin(coleta_aed(), moldura_aed(), "roi")
  expect_equal(res$teste, c("Kruskal-Wallis (estratos)", "Spearman (buy-in)"))
  expect_gt(res$estatistica[2], 0.8)
  expect_true(all(res$p_valor >= 0 & res$p_valor <= 1))
})

test_that("graficos desenham sem erro", {
  arquivo <- tempfile(fileext = ".png")
  grDevices::png(arquivo)
  col <- coleta_aed()
  col$roi[1] <- 500
  expect_silent(grafico_moldura_estratos(moldura_aed()))
  expect_silent(grafico_roi_estratos(col, teto = 100))
  grDevices::dev.off()
  expect_true(file.exists(arquivo))
})
