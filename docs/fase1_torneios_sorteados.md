# Fase 1 — Torneios sorteados

Versão em Markdown de [`data/raw/sharkscope/torneios_sorteados.csv`](../data/raw/sharkscope/torneios_sorteados.csv), com o nome, o horário e o formato de cada torneio tirados de [`listagem_torneios.csv`](../data/raw/sharkscope/listagem_torneios.csv). O CSV é a fonte oficial; este arquivo é só para leitura.

Sorteio: AAS sem reposição de $`n_{jh}`$ = 2 torneios por (bloco, estrato), semente 164363 com sementes derivadas por célula ([`R/sorteio.R`](../R/sorteio.R)). $`M_k`$ é o total de entradas da fonte, com re-entries ([Metodologia §2.4](Metodologia.md#24-variáveis-de-interesse)). Horários de Brasília.

## Bloco 5 — 18/10 04:00 a 06:00 (domingo)

| Estrato | `torneio_id` | Nome | Início | Buy-in (US$) | $`M_k`$ (entradas) | $`N_{jh}`$ | $`n_{jh}`$ | Formato |
|---|---|---|---|---:|---:|---:|---:|---|
| Micro | 4039583402 | Big 4.40 | 04:19 | 4,40 | 114 | 7 | 2 | MTT |
| Micro | 4039581366 | Hotter | 05:16 | 2,20 | 200 | 7 | 2 | Progressive KO |
| Low | 4039583280 | Bounty Builder 11 | 05:07 | 11,00 | 180 | 8 | 2 | Bounty Builder |
| Low | 4038334525 | Mini Faster | 05:50 | 11,00 | 137 | 8 | 2 | 8-max |
| Mid/High | 4039581390 | Hotter Hyper | 04:28 | 55,00 | 15 | 3 | 2 | Hyper |
| Mid/High | 4038334524 | Pacific Warm Up | 04:37 | 82,00 | 29 | 3 | 2 | MTT |

## Bloco 8 — 18/10 10:00 a 12:00 (domingo)

| Estrato | `torneio_id` | Nome | Início | Buy-in (US$) | $`M_k`$ (entradas) | $`N_{jh}`$ | $`n_{jh}`$ | Formato |
|---|---|---|---|---:|---:|---:|---:|---|
| Micro | 4039582737 | Rounder | 11:03 | 1,10 | 107 | 8 | 2 | MTT |
| Micro | 4039583321 | Bigger | 11:16 | 3,30 | 112 | 8 | 2 | MTT |
| Low | 4039583060 | Bounty Builder 11 | 11:18 | 11,00 | 274 | 8 | 2 | Bounty Builder |
| Low | 4039582436 | NLHE | 11:23 | 11,00 | 85 | 8 | 2 | 6-max |
| Mid/High | 4038334542 | Fast 6 | 10:36 | 33,00 | 62 | 5 | 2 | 6-max |
| Mid/High | 4039581475 | Hotter 27 | 11:41 | 27,00 | 71 | 5 | 2 | Progressive KO |

## Bloco 24 — 19/10 18:00 a 20:00 (segunda)

| Estrato | `torneio_id` | Nome | Início | Buy-in (US$) | $`M_k`$ (entradas) | $`N_{jh}`$ | $`n_{jh}`$ | Formato |
|---|---|---|---|---:|---:|---:|---:|---|
| Micro | 4040093393 | NLHE | 18:19 | 3,30 | 90 | 9 | 2 | Turbo |
| Micro | 4040092391 | Hot Hyper | 18:37 | 2,20 | 336 | 9 | 2 | Progressive KO |
| Low | 4040092434 | Hot Hyper | 19:28 | 11,00 | 325 | 11 | 2 | Hyper |
| Low | 4040092383 | Hot 22 | 19:50 | 22,00 | 257 | 11 | 2 | Progressive KO |
| Mid/High | 4040087750 | Bounty Builder 44 | 18:09 | 44,00 | 106 | 7 | 2 | Bounty Builder |
| Mid/High | 4040086613 | Bounty Builder 530 | 19:30 | 530,00 | 50 | 7 | 2 | High Roller |

## Resumo por estrato

| Estrato | Torneios sorteados | Soma de $`M_k`$ |
|---|---:|---:|
| Micro | 6 | 959 |
| Low | 6 | 1258 |
| Mid/High | 6 | 333 |
| **Total** | **18** | **2550** |
