# Fase 1 — Torneios sorteados

Versão em Markdown de [`data/raw/sharkscope/torneios_sorteados.csv`](../data/raw/sharkscope/torneios_sorteados.csv), com o nome, o horário e o formato de cada torneio tirados de [`listagem_torneios.csv`](../data/raw/sharkscope/listagem_torneios.csv). O CSV é a fonte oficial; este arquivo é só para leitura e é gerado por `Rscript scripts/gerar_md_torneios.R`.

Sorteio: AAS sem reposição de $`n_{jh}`$ = 2 torneios por (bloco, estrato), semente 164363 com sementes derivadas por célula ([`R/sorteio.R`](../R/sorteio.R)). $`M_k`$ é o total de entradas da fonte, com re-entries ([Metodologia §2.4](Metodologia.md#24-variáveis-de-interesse)). Horários de Brasília.

Torneios extras: nas células que ficaram com menos de 2 torneios com $`m_k \ge 2`$ respondentes, o próximo torneio da mesma permutação da célula foi sorteado (`sortear_amostra.R torneio-extra`, [ADR-011](../.ai/modelagem.md)). Eles aparecem como "extra" na coluna Sorteio, e $`n_{jh}`$ é o total sorteado na célula.

## Bloco 5 — 18/10 04:00 a 06:00 (domingo)

| Estrato | `torneio_id` | Nome | Início | Buy-in (US$) | $`M_k`$ (entradas) | $`N_{jh}`$ | $`n_{jh}`$ | Formato | Sorteio |
|---|---|---|---|---:|---:|---:|---:|---|---|
| Micro | 4039583402 | Big 4.40 | 04:19 | 4,40 | 114 | 7 | 3 | MTT | original |
| Micro | 4039581366 | Hotter | 05:16 | 2,20 | 200 | 7 | 3 | Progressive KO | original |
| Micro | 4039582664 | Turbo | 05:51 | 1,10 | 247 | 7 | 3 | Progressive KO | extra |
| Low | 4039583266 | Bounty Builder 22 | 04:22 | 22,00 | 142 | 8 | 3 | Bounty Builder | extra |
| Low | 4039583280 | Bounty Builder 11 | 05:07 | 11,00 | 180 | 8 | 3 | Bounty Builder | original |
| Low | 4038334525 | Mini Faster | 05:50 | 11,00 | 137 | 8 | 3 | 8-max | original |
| Mid/High | 4039581390 | Hotter Hyper | 04:28 | 55,00 | 15 | 3 | 2 | Hyper | original |
| Mid/High | 4038334524 | Pacific Warm Up | 04:37 | 82,00 | 29 | 3 | 2 | MTT | original |

## Bloco 8 — 18/10 10:00 a 12:00 (domingo)

| Estrato | `torneio_id` | Nome | Início | Buy-in (US$) | $`M_k`$ (entradas) | $`N_{jh}`$ | $`n_{jh}`$ | Formato | Sorteio |
|---|---|---|---|---:|---:|---:|---:|---|---|
| Micro | 4039582737 | Rounder | 11:03 | 1,10 | 107 | 8 | 2 | MTT | original |
| Micro | 4039583321 | Bigger | 11:16 | 3,30 | 112 | 8 | 2 | MTT | original |
| Low | 4039582706 | Progressive KO | 10:19 | 5,50 | 62 | 8 | 4 | Progressive KO | extra |
| Low | 4039581466 | Hotter 5.50 | 11:04 | 5,50 | 171 | 8 | 4 | Progressive KO | extra |
| Low | 4039583060 | Bounty Builder 11 | 11:18 | 11,00 | 274 | 8 | 4 | Bounty Builder | original |
| Low | 4039582436 | NLHE | 11:23 | 11,00 | 85 | 8 | 4 | 6-max | original |
| Mid/High | 4038334542 | Fast 6 | 10:36 | 33,00 | 62 | 5 | 2 | 6-max | original |
| Mid/High | 4039581475 | Hotter 27 | 11:41 | 27,00 | 71 | 5 | 2 | Progressive KO | original |

## Bloco 24 — 19/10 18:00 a 20:00 (segunda)

| Estrato | `torneio_id` | Nome | Início | Buy-in (US$) | $`M_k`$ (entradas) | $`N_{jh}`$ | $`n_{jh}`$ | Formato | Sorteio |
|---|---|---|---|---:|---:|---:|---:|---|---|
| Micro | 4040093364 | NLHE | 18:19 | 1,10 | 207 | 9 | 4 | 6-max | extra |
| Micro | 4040093393 | NLHE | 18:19 | 3,30 | 90 | 9 | 4 | Turbo | original |
| Micro | 4040092391 | Hot Hyper | 18:37 | 2,20 | 336 | 9 | 4 | Progressive KO | original |
| Micro | 4040085450 | Mini Eliminator | 19:17 | 4,40 | 933 | 9 | 4 | Progressive KO | extra |
| Low | 4040092434 | Hot Hyper | 19:28 | 11,00 | 325 | 11 | 2 | Hyper | original |
| Low | 4040092383 | Hot 22 | 19:50 | 22,00 | 257 | 11 | 2 | Progressive KO | original |
| Mid/High | 4040087750 | Bounty Builder 44 | 18:09 | 44,00 | 106 | 7 | 2 | Bounty Builder | original |
| Mid/High | 4040086613 | Bounty Builder 530 | 19:30 | 530,00 | 50 | 7 | 2 | High Roller | original |

## Bloco 30 — 20/10 06:00 a 08:00 (terça)

| Estrato | `torneio_id` | Nome | Início | Buy-in (US$) | $`M_k`$ (entradas) | $`N_{jh}`$ | $`n_{jh}`$ | Formato | Sorteio |
|---|---|---|---|---:|---:|---:|---:|---|---|
| Micro | 4040093464 | NLHE | 07:05 | 2,20 | 92 | 3 | 3 | Turbo | original |
| Micro | 4040092069 | Hot 2.20 | 07:09 | 2,20 | 91 | 3 | 3 | MTT | extra |
| Micro | 4040092095 | Hot Hyper | 07:16 | 4,40 | 64 | 3 | 3 | Hyper | original |
| Low | 4040087687 | Bounty Adrenaline | 06:53 | 5,50 | 53 | 9 | 3 | Short | extra |
| Low | 4040087659 | Bounty Builder 22 | 07:16 | 22,00 | 61 | 9 | 3 | Bounty Builder | original |
| Low | 4040092085 | Hot 16.5 | 07:35 | 16,50 | 53 | 9 | 3 | Progressive KO | original |
| Mid/High | 4040085499 | Pacific Rim Special | 06:24 | 109,00 | 23 | 5 | 2 | MTT | original |
| Mid/High | 4040087674 | Bounty Builder 82 | 07:52 | 82,00 | 26 | 5 | 2 | Bounty Builder | original |

## Resumo por estrato

| Estrato | Torneios sorteados | Soma de $`M_k`$ |
|---|---:|---:|
| Micro | 12 | 2593 |
| Low | 12 | 1800 |
| Mid/High | 8 | 382 |
| **Total** | **32** | **4775** |
