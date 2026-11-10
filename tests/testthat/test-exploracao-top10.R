# Testes de `R/exploracao_top10.R`, com dados pequenos calculados a mao.

# Dois torneios (micro e low) no bloco 1 e um torneio low no bloco 2, para o
# estimador do plano rodar (b = 2). Amostra: 4 posicoes por torneio, uma
# delas dentro do top 10 (posicao 3) no torneio "a".
moldura_t10 <- function() {
  data.frame(
    bloco_id = c(1L, 1L, 1L, 1L, 2L, 2L, 2L, 2L),
    estrato = c("micro", "micro", "low", "low", "micro", "micro", "low", "low"),
    torneio_id = c("a", "a2", "b", "b2", "c", "c2", "d", "d2"),
    buy_in = c(2, 2, 10, 10, 2, 2, 10, 10),
    n_inscritos = 50,
    stringsAsFactors = FALSE
  )
}

coleta_t10 <- function() {
  torneios <- c("a", "a2", "b", "b2", "c", "c2", "d", "d2")
  m <- moldura_t10()
  data.frame(
    estrato = rep(m$estrato, each = 4),
    bloco_id = rep(m$bloco_id, each = 4),
    torneio_id = rep(torneios, each = 4),
    n_inscritos = 50,
    posicao = rep(c(3L, 20L, 30L, 40L), 8),
    nickname = c("p3", paste0("x", 2:32)),
    respondeu = rep(c(TRUE, TRUE, TRUE, FALSE), 8),
    roi = rep(c(10, 20, -5, NA), 8),
    lucro = rep(c(1, 1, -1, NA), 8),
    n_jogos_dia = 2,
    data_consulta = "2026-10-22",
    stringsAsFactors = FALSE
  ) |>
    within({
      lucrativo <- as.integer(roi > 0)
      lucrativo_estrito <- as.integer(roi > 0 & lucro > 0)
    })
}

top10_t10 <- function() {
  data.frame(
    bloco_id = 1L,
    torneio_id = rep(c("a", "b"), each = 4),
    posicao = rep(c(1L, 2L, 3L, 4L), 2),
    nickname = c("v1", "Anônimo", "p3[2]", "v4", "w1", "w2", "w3", "w4"),
    data_anotacao = "2026-10-20",
    data_consulta = "2026-11-05",
    respondeu = c(TRUE, FALSE, TRUE, NA, TRUE, TRUE, FALSE, TRUE),
    roi = c(30, NA, 10.5, NA, 15, -10, NA, 25),
    lucro = c(5, NA, 1, NA, 2, -3, NA, -1),
    n_jogos_dia = 3,
    stringsAsFactors = FALSE
  )
}

test_that("nome_sem_sufixo tira so o sufixo de re-entrada", {
  expect_equal(
    nome_sem_sufixo(c("comistus[2]", "a[b]", "x[10]", "y")),
    c("comistus", "a[b]", "x", "y")
  )
})

test_that("preparar_top10 fica com os consultados e deriva as colunas", {
  tp <- preparar_top10(top10_t10(), moldura_t10())
  expect_equal(nrow(tp), 7) # 1 linha nao consultada (NA) sai
  expect_equal(tp$estrato, c(rep("micro", 3), rep("low", 4)))
  expect_equal(tp$anonimo, c(FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE))
  expect_equal(tp$nickname[3], "p3")
  expect_equal(tp$lucrativo_estrito[tp$respondeu], c(1, 1, 1, 0, 0))
  m <- moldura_t10()
  m <- m[m$torneio_id != "b", ]
  expect_error(preparar_top10(top10_t10(), m), "ausente")
})

test_that("resposta do top 10 por estrato e por posicao", {
  tp <- preparar_top10(top10_t10(), moldura_t10())
  est <- resumir_resposta_top10(tp, "estrato")
  expect_equal(est$estrato, c("micro", "low", "total"))
  expect_equal(est$consultados, c(3, 4, 7))
  expect_equal(est$taxa_resposta, c(2 / 3, 3 / 4, 5 / 7))
  expect_equal(est$anonimos, c(1, 0, 1))
  expect_equal(est$roi_mediana[1], 20.25)
  pos <- resumir_resposta_top10(tp, "posicao")
  expect_equal(pos$posicao, c("1", "2", "3", "4", "total"))
  expect_equal(pos$taxa_resposta[1:4], c(1, 0.5, 0.5, 1))
})

test_that("reconsultas casam torneio e posicao e comparam o ROI", {
  tp <- preparar_top10(top10_t10(), moldura_t10())
  rc <- conferir_reconsultas(tp, coleta_t10())
  expect_equal(nrow(rc), 2) # posicao 3 de "a" e de "b"
  a <- rc[rc$torneio_id == "a", ]
  expect_true(a$mesmo_nickname)
  expect_equal(a$dif_roi, 0.5)
  b <- rc[rc$torneio_id == "b", ]
  expect_false(b$respondeu_top10)
  expect_true(b$respondeu_amostra)
})

test_that("grupos usam so os torneios do top 10 e a amostra fora do top 10", {
  tp <- preparar_top10(top10_t10(), moldura_t10())
  g <- montar_grupos_top10(tp, coleta_t10())
  amo <- g[g$grupo == GRUPO_AMOSTRA_FORA, ]
  expect_equal(sort(unique(amo$torneio_id)), c("a", "b"))
  expect_true(all(amo$posicao > 10))
  expect_equal(nrow(amo), 6)
  res <- resumir_grupos_top10(g)
  expect_equal(res$respondentes, c(5, 4))
  expect_equal(res$taxa_resposta, c(5 / 7, 4 / 6))
  expect_equal(res$roi_mediana[2], 7.5)
  por_estrato <- resumir_grupos_top10(g, por_estrato = TRUE)
  expect_equal(por_estrato$estrato, c("micro", "micro", "low", "low"))
})

test_that("comparacao por torneio e testes", {
  tp <- preparar_top10(top10_t10(), moldura_t10())
  g <- montar_grupos_top10(tp, coleta_t10())
  pt <- comparar_por_torneio_top10(g)
  expect_equal(pt$torneio_id, c("a", "b"))
  expect_equal(pt$mediana_top10, c(20.25, 15))
  expect_equal(pt$dif_mediana, c(20.25 - 7.5, 15 - 7.5))
  te <- testar_top10(g, pt, tp)
  expect_equal(nrow(te), 6)
  expect_true(all(te$p_valor >= 0 & te$p_valor <= 1))
})

test_that("tabela de referencia junta plano, amostra e top 10", {
  tp <- preparar_top10(top10_t10(), moldura_t10())
  col <- coleta_t10()
  g <- montar_grupos_top10(tp, col)
  kaggle <- data.frame(roi = c(-50, 10), lucrativo = c(0L, 1L))
  ref <- tabela_referencia_top10(g, col, moldura_t10(), B = 10, populacao_kaggle = kaggle)
  expect_equal(nrow(ref), 5)
  expect_equal(ref$roi_media[1], -20)
  expect_equal(ref$n[3], 24)
  plano <- estimar_media_tres_estagios(col, moldura_t10(), 10, "roi", unidade = "jogador")
  expect_equal(ref$roi_media[2], plano$estimativa)
  expect_equal(nrow(tabela_referencia_top10(g, col, moldura_t10(), B = 10)), 4)
})

test_that("graficos do top 10 desenham sem erro", {
  tp <- preparar_top10(top10_t10(), moldura_t10())
  tp$roi[1] <- 300
  g <- montar_grupos_top10(tp, coleta_t10())
  arquivo <- tempfile(fileext = ".png")
  grDevices::png(arquivo, width = 900, height = 400)
  expect_silent(grafico_top10_posicao(tp))
  expect_silent(grafico_top10_vs_amostra(g, referencia = 5))
  grDevices::dev.off()
  expect_true(file.exists(arquivo))
})
