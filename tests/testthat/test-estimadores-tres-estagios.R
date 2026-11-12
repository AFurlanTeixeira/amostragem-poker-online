# Testes de `R/estimadores_tres_estagios.R`.
#
# Base: Exemplos 1 e 2 do Thompson (2012), §13.1 (p. 174-176), os mesmos de
# test-estimadores-dois-estagios.R, colocados dentro de blocos de tempo.

coleta_bloco <- function(bloco_id, fator = 1) {
  data.frame(
    bloco_id = bloco_id,
    estrato = "A",
    torneio_id = paste0(rep(c("t1", "t2", "t3"), each = 2), "_", bloco_id),
    n_inscritos = rep(c(24, 20, 15), each = 2),
    nickname = paste0("j", 1:6),
    respondeu = TRUE,
    roi = fator * c(8, 12, 0, 0, 1, 3),
    lucro = 0,
    n_jogos_dia = 2,
    stringsAsFactors = FALSE
  )
}

moldura_bloco <- function(bloco_id) {
  data.frame(
    bloco_id = bloco_id,
    estrato = "A",
    torneio_id = paste0(c("t1", "t2", "t3", paste0("x", 1:97)), "_", bloco_id),
    buy_in = 1,
    n_inscritos = c(24, 20, 15, rep(25, 96), 41),
    stringsAsFactors = FALSE
  )
}

test_that("com um unico bloco (b = B = 1) reproduz o Exemplo 2 do Thompson", {
  res <- estimar_media_tres_estagios(
    coleta_bloco(1), moldura_bloco(1), B = 1, unidade = "inscricao"
  )
  expect_equal(res$estimativa * 2500, 11441, tolerance = 1e-4)
  # Var(Z) do estimador razao; Thompson arredonda r = 4,58 e obtem 43.426.788.
  expect_equal(res$variancia * res$N_hat^2, 43426788, tolerance = 5e-3)
})

test_that("total e variancia em tres estagios batem com a conta a mao", {
  resp <- rbind(coleta_bloco(1), coleta_bloco(2, fator = 2))
  N_jh <- c("1|A" = 100, "2|A" = 100)
  tot <- total_tres_estagios(resp, resp$roi, N_jh, B = 5)
  # Blocos: Y_1 = 9000, Y_2 = 18000 (Exemplo 1); v_1 = 55.366.900, v_2 = 4 v_1.
  expect_equal(tot$blocos$Y_j, c(9000, 18000))
  expect_equal(tot$total, 5 / 2 * 27000)
  # 25 (1 - 2/5) var(9000, 18000) / 2 + (5/2)(5 * 55.366.900)
  expect_equal(tot$variancia, 303750000 + 692086250)
  expect_equal(unname(tot$termos), c(303750000, 692086250))
})

test_that("componentes de variancia nao viesados somam a variancia", {
  resp <- rbind(coleta_bloco(1), coleta_bloco(2, fator = 2))
  N_jh <- c("1|A" = 100, "2|A" = 100)
  tot <- total_tres_estagios(resp, resp$roi, N_jh, B = 5)
  # Bloco 1 (Exemplo 1): entre torneios 55.290.000, dentro 76.900; bloco 2 = 4x.
  # dentro dos torneios: (B/b)^2 (N/n) 76.900 x 5
  dentro <- 6.25 * (100 / 3) * 76900 * 5
  # entre torneios: (B/b)^2 [55.290.000 - (1 - 3/100)(100/3) 76.900] x 5
  entre_tor <- 6.25 * (55290000 - 0.97 * (100 / 3) * 76900) * 5
  # entre blocos: 25 (1 - 2/5) [var(9000, 18000) - media(v_j)] / 2 (negativo)
  entre_blocos <- 7.5 * (40500000 - 2.5 * 55366900)
  expect_equal(
    tot$componentes,
    c(entre_blocos = entre_blocos, entre_torneios = entre_tor, dentro_torneios = dentro)
  )
  expect_equal(sum(tot$componentes), tot$variancia)

  # Na razao, termos e componentes vem na escala de R e somam a variancia.
  moldura <- rbind(moldura_bloco(1), moldura_bloco(2))
  res <- estimar_media_tres_estagios(resp, moldura, B = 5, unidade = "inscricao")
  expect_equal(sum(res$termos), res$variancia)
  expect_equal(sum(res$componentes), res$variancia)
  expect_equal(nrow(res$blocos_z), 2)

  # Censo de blocos (b = B): nao ha componente entre blocos.
  censo <- total_tres_estagios(resp, resp$roi, N_jh, B = 2)
  expect_equal(censo$componentes[["entre_blocos"]], 0)
  expect_equal(sum(censo$componentes), censo$variancia)
})

test_that("estimativa e a media ponderada pelos pesos finais", {
  coleta <- rbind(coleta_bloco(1), coleta_bloco(2, fator = 2))
  moldura <- rbind(moldura_bloco(1), moldura_bloco(2))
  moldura <- moldura[-(10:30), ] # N_jh diferentes entre os blocos
  res <- estimar_media_tres_estagios(coleta, moldura, B = 10, unidade = "inscricao")
  a <- res$amostra
  expect_equal(res$estimativa, sum(a$w * a$y) / sum(a$w))
  expect_equal(res$gl, 1)
})

test_that("por jogador com frequencia constante coincide com por inscricao", {
  coleta <- rbind(coleta_bloco(1), coleta_bloco(2, fator = 2))
  moldura <- rbind(moldura_bloco(1), moldura_bloco(2))
  por_insc <- estimar_media_tres_estagios(coleta, moldura, B = 10, unidade = "inscricao")
  por_jog <- estimar_media_tres_estagios(coleta, moldura, B = 10, unidade = "jogador")
  expect_equal(por_jog$estimativa, por_insc$estimativa)
  expect_equal(por_jog$variancia, por_insc$variancia)
  expect_equal(por_jog$N_hat, por_insc$N_hat / frequencia_no_periodo(2))
})

test_that("jogador frequente pesa menos por jogador do que por inscricao", {
  coleta <- rbind(coleta_bloco(1), coleta_bloco(2, fator = 2))
  coleta$n_jogos_dia[coleta$roi > 0] <- 20 # quem lucra joga mais
  moldura <- rbind(moldura_bloco(1), moldura_bloco(2))
  por_insc <- estimar_media_tres_estagios(coleta, moldura, B = 10, unidade = "inscricao")
  por_jog <- estimar_media_tres_estagios(coleta, moldura, B = 10, unidade = "jogador")
  expect_lt(por_jog$estimativa, por_insc$estimativa)
})

test_that("frequencia tem minimo 1 e n_jogos_dia e exigido por jogador", {
  expect_equal(frequencia_no_periodo(c(0.1, 3)), c(1, 3 * 76 / 24))
  coleta <- rbind(coleta_bloco(1), coleta_bloco(2))
  coleta$n_jogos_dia[1] <- NA
  moldura <- rbind(moldura_bloco(1), moldura_bloco(2))
  expect_error(estimar_media_tres_estagios(coleta, moldura, B = 10), "n_jogos_dia")
  expect_silent(estimar_media_tres_estagios(coleta, moldura, B = 10, unidade = "inscricao"))
})

test_that("torneio com 1 respondente sai da estimacao (ADR-011)", {
  coleta <- rbind(coleta_bloco(1), coleta_bloco(2))
  coleta <- rbind(coleta, transform(coleta_bloco(1)[1:2, ], torneio_id = "t4_1"))
  moldura <- rbind(moldura_bloco(1), moldura_bloco(2))
  moldura$torneio_id[4] <- "t4_1"
  sem_t4 <- estimar_media_tres_estagios(coleta[1:12, ], moldura, B = 10)
  coleta$respondeu[13] <- FALSE
  com_t4 <- estimar_media_tres_estagios(coleta, moldura, B = 10)
  expect_equal(com_t4$estimativa, sem_t4$estimativa)
  expect_equal(com_t4$variancia, sem_t4$variancia)
  expect_equal(com_t4$torneios_excluidos, "t4_1")
})

test_that("minimos por celula e por bloco sao exigidos", {
  coleta <- rbind(coleta_bloco(1), coleta_bloco(2))
  moldura <- rbind(moldura_bloco(1), moldura_bloco(2))
  coleta$respondeu[c(1, 3)] <- FALSE # t1_1 e t2_1 ficam com 1 respondente
  expect_error(estimar_media_tres_estagios(coleta, moldura, B = 10), "menos de 2 torneios")
  expect_error(estimar_media_tres_estagios(coleta_bloco(1), moldura_bloco(1), B = 10), "2 blocos")
})

test_that("jackknife JK1 retira um bloco por vez", {
  # Blocos iguais exceto o ROI (fatores 1, 2, 3): o denominador por bloco e o
  # mesmo, entao R_(j) = c x media dos fatores restantes, c = 9000 / Y_j(1).
  coleta <- rbind(coleta_bloco(1), coleta_bloco(2, fator = 2), coleta_bloco(3, fator = 3))
  moldura <- rbind(moldura_bloco(1), moldura_bloco(2), moldura_bloco(3))
  res <- estimar_media_tres_estagios(coleta, moldura, B = 10, unidade = "inscricao")
  c_ <- 9000 / ((100 / 3) * (24 + 20 + 15))
  # (b-1)/b sum (R_(j) - R)^2 = (2/3) c^2 (0,5^2 + 0 + 0,5^2)
  expect_equal(res$variancia_jk1, c_^2 / 3)
  # Var(Z) exposta para trocar o denominador (N verdadeiro na simulacao).
  expect_equal(res$variancia_z / res$N_hat^2, res$variancia)
})

test_that("EPA e coerente com rho_int", {
  coleta <- rbind(coleta_bloco(1), coleta_bloco(2, fator = 2))
  moldura <- rbind(moldura_bloco(1), moldura_bloco(2))
  res <- estimar_media_tres_estagios(coleta, moldura, B = 10)
  epa <- calcular_epa_tres_estagios(res)
  expect_gt(epa$epa, 0)
  expect_equal(epa$m_medio, 2)
  expect_equal(epa$rho_int, (epa$epa - 1) / (epa$m_medio - 1))
})
