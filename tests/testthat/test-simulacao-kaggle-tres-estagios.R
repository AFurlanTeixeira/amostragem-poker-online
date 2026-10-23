# Testes de `R/simulacao_kaggle_tres_estagios.R`.
#
# Populacao e moldura fabricadas (nao sao o Kaggle nem a listagem real).

kaggle_fabricado_estratos <- function() {
  set.seed(3)
  n <- c(micro = 80, low = 120, mid_high = 150)
  estrato <- rep(names(n), n)
  media <- c(micro = -40, low = -30, mid_high = -20)[estrato]
  roi <- rnorm(length(estrato), mean = media, sd = 30)
  data.frame(
    player_id = sprintf("P%03d", seq_along(estrato)),
    roi = roi,
    lucrativo = as.integer(roi > 0),
    n_torneios = sample(10:500, length(estrato), replace = TRUE),
    estrato = estrato,
    stringsAsFactors = FALSE
  )
}

moldura_campo_fabricada <- function() {
  estratos <- c("micro", "low", "mid_high")
  data.frame(
    bloco_id = rep(c(5, 8), times = c(10, 11)),
    estrato = c(rep(estratos, c(3, 4, 3)), rep(estratos, c(4, 4, 3))),
    torneio_id = paste0("t", 1:21),
    buy_in = 1,
    n_inscritos = c(
      20, 35, 50, 12, 18, 25, 40, 8, 10, 15, 22, 30, 45, 60, 14, 20, 26, 33, 9, 12, 16
    ),
    stringsAsFactors = FALSE
  )
}

pop_fabricada <- function() {
  montar_populacao_blocos(kaggle_fabricado_estratos(), moldura_campo_fabricada(), B = 8, seed = 1)
}

test_that("populacao sintetica respeita estratos, M_k e f_i", {
  kag <- kaggle_fabricado_estratos()
  pop <- pop_fabricada()
  expect_identical(pop, montar_populacao_blocos(kag, moldura_campo_fabricada(), 8, 1))
  expect_setequal(unique(pop$torneios$bloco_id), 1:8)
  expect_true(all(pop$torneios$n_inscritos %in% moldura_campo_fabricada()$n_inscritos))
  # Jogador do estrato do torneio, uma vez por torneio, posicoes 1..M_k.
  estrato_jogador <- stats::setNames(kag$estrato, kag$player_id)
  expect_equal(unname(estrato_jogador[pop$inscricoes$player_id]), pop$inscricoes$estrato)
  expect_false(anyDuplicated(pop$inscricoes[, c("torneio_id", "player_id")]) > 0)
  expect_equal(as.numeric(table(pop$inscricoes$torneio_id)[pop$torneios$torneio_id]),
               pop$torneios$n_inscritos)
  # f_i e o numero de inscricoes do jogador; `inicio` acha a linha da posicao.
  expect_equal(sum(pop$jogadores$f_i), nrow(pop$inscricoes))
  k <- pop$torneios$torneio_id[5]
  expect_equal(pop$inscricoes$torneio_id[pop$inicio[[k]] + 3], k)
  expect_equal(pop$inscricoes$posicao[pop$inicio[[k]] + 3], 3)
})

test_that("parametro por jogador conta cada jogador uma vez", {
  pop <- pop_fabricada()
  v <- parametros_verdadeiros(pop)
  expect_equal(v$valor[v$unidade == "jogador" & v$variavel == "roi"], mean(pop$jogadores$roi))
  # Por jogador = razao de y/f por 1/f nas inscricoes (Metodologia §7.5).
  ins <- pop$inscricoes
  expect_equal(sum(ins$roi / ins$f_i) / sum(1 / ins$f_i), mean(pop$jogadores$roi))
})

test_that("sorteio usa os mesmos estagios do campo e acha os jogadores certos", {
  pop <- pop_fabricada()
  a <- sortear_amostra_kaggle(pop, b = 3, n_jh = 2, m_k = 5, seed = 7)
  expect_length(a$blocos, 3)
  expect_true(all(table(a$sorteados$bloco_id, a$sorteados$estrato) == 2))
  expect_true(all(table(a$coleta$torneio_id) == 5))
  chave <- paste(pop$inscricoes$torneio_id, pop$inscricoes$posicao)
  linha <- match(paste(a$coleta$torneio_id, a$coleta$posicao), chave)
  expect_equal(a$coleta$player_id, pop$inscricoes$player_id[linha])
  expect_equal(a$coleta$f_i, pop$inscricoes$f_i[linha])
})

test_that("f_i conhecido tem prioridade sobre n_jogos_dia", {
  pop <- pop_fabricada()
  a <- sortear_amostra_kaggle(pop, b = 3, n_jh = 2, m_k = 5, seed = 7)
  com_f <- estimar_media_tres_estagios(a$coleta, a$moldura, 8, "roi")
  sem_f <- a$coleta
  sem_f$n_jogos_dia <- sem_f$f_i / DIAS_PERIODO # frequencia_no_periodo() devolve f_i
  sem_f$f_i <- NULL
  expect_equal(com_f$estimativa, estimar_media_tres_estagios(sem_f, a$moldura, 8, "roi")$estimativa)
})

test_that("regra de torneios extras deixa todas as celulas estimaveis", {
  pop <- pop_fabricada()
  taxas <- c(micro = 0.6, low = 0.6, mid_high = 0.6)
  a <- sortear_amostra_kaggle(pop, b = 3, n_jh = 2, m_k = 5, seed = 11, taxas)
  a <- aplicar_torneios_extras(pop, a, 5, 11, taxas)
  expect_equal(nrow(celulas_abaixo_do_minimo(a)), 0)
  expect_false(is.null(a$eventos))
  expect_silent(estimar_media_tres_estagios(a$coleta, a$moldura, 8, "roi"))
})

test_that("colapso junta a celula com o estrato vizinho do mesmo bloco", {
  pop <- pop_fabricada()
  a <- sortear_amostra_kaggle(pop, b = 3, n_jh = 2, m_k = 5, seed = 7)
  j <- a$blocos[1]
  c2 <- colapsar_celula(a, j, "mid_high")
  expect_true(all(c2$moldura$estrato[c2$moldura$bloco_id == j] %in% c("low+mid_high", "micro")))
  expect_equal(sum(c2$sorteados$estrato == "low+mid_high"), 4)
  expect_equal(c2$coleta$estrato[c2$coleta$bloco_id != j], a$coleta$estrato[a$coleta$bloco_id != j])
  expect_equal(estrato_original("low+mid_high"), "low")
})

test_that("Monte Carlo: plano em tres estagios aproximadamente nao viesado", {
  pop <- pop_fabricada()
  sims <- simular_tres_estagios(pop, b = 4, n_rep = 150, seed = 5)
  resumo <- resumir_tres_estagios(sims, parametros_verdadeiros(pop))
  expect_setequal(unique(resumo$plano), c("tres_estagios", "AAS"))
  roi <- resumo[resumo$variavel == "roi", ]
  expect_true(all(abs(roi$vies) < 4)) # ROI com DP ~ 30 p.p.
  expect_true(all(resumo$cobertura_wald[resumo$plano == "AAS"] > 0.88))
  expect_equal(resumo$epa_empirico[resumo$plano == "AAS"], rep(1, 4))
})
