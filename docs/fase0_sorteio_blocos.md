# Fase 0 — Sorteio dos blocos de tempo

Registro da execução da Fase 0 do protocolo de coleta ([`Metodologia.md` §6](Metodologia.md#6-protocolo-de-coleta)): sorteio das unidades primárias de amostragem (UPA) do estágio temporal.

Data de execução do sorteio oficial: 19/10/2026, 23:29 (horário de Brasília)

---

## 1. Parâmetros

| Parâmetro | Valor |
|---|---|
| Período de referência | 17/10/2026 20:00 a 21/10/2026 00:00 (76 h) |
| Duração do bloco | 2 h |
| Fuso horário | `America/Sao_Paulo` (horário de Brasília, UTC−3, sem horário de verão) |
| $B$ (blocos na moldura) | 38 = 76 h / 2 h |
| $b$ (blocos sorteados) | 6 |
| Plano | AAS sem reposição (AASs) |
| Semente | 164363 |
| Probabilidade de inclusão de cada bloco | $b/B = 6/38 \approx 0{,}158$ |
| Peso do 1º estágio | $B/b = 38/6 \approx 6{,}33$ |
| $b$ efetivo (após a perda dos blocos 34 e 36, §7) | 4, peso do 1º estágio $38/4 = 9{,}5$ |

## 2. Procedimento

1. **Moldura:** a função `gerar_blocos()` ([`R/sorteio.R`](../R/sorteio.R)) gera os 38 blocos consecutivos de 2 h, numerados por `bloco_id` de 1 a 38 em ordem cronológica. O bloco 1 começa em 17/10/2026 20:00, e o bloco 38 termina em 21/10/2026 00:00.
2. **Sorteio:** a função `sortear_blocos()` sorteia 6 blocos distintos com `sample.int()` do R, usando a semente acima. O sorteio não altera o estado global do gerador de números aleatórios. A semente é a mesma registrada antes do primeiro sorteio (ver §4).
3. **Registro:** o resultado foi salvo em [`data/raw/sharkscope/blocos_sorteados.csv`](../data/raw/sharkscope/blocos_sorteados.csv), e o evento foi registrado em [`data/raw/sharkscope/log_coleta.csv`](../data/raw/sharkscope/log_coleta.csv).

Para reproduzir o sorteio:

```bash
Rscript scripts/sortear_amostra.R blocos --n-blocos 6 --seed 164363
```

As opções `--inicio`, `--fim`, `--horas-bloco` e `--fuso` têm como padrão os valores da tabela acima.

## 3. Resultado

| Ordem do sorteio | `bloco_id` | Início (Brasília) | Fim (Brasília) | Início (UTC) | Dia da semana |
|---|---|---|---|---|---|
| 6 | 5 | 18/10/2026 04:00 | 18/10/2026 06:00 | 18/10 07:00 | domingo |
| 4 | 8 | 18/10/2026 10:00 | 18/10/2026 12:00 | 18/10 13:00 | domingo |
| 5 | 24 | 19/10/2026 18:00 | 19/10/2026 20:00 | 19/10 21:00 | segunda |
| 2 | 30 | 20/10/2026 06:00 | 20/10/2026 08:00 | 20/10 09:00 | terça |
| 1 | 34 | 20/10/2026 14:00 | 20/10/2026 16:00 | 20/10 17:00 | terça |
| 3 | 36 | 20/10/2026 18:00 | 20/10/2026 20:00 | 20/10 21:00 | terça |

A tabela está em ordem cronológica. A coluna "Ordem do sorteio" indica a ordem em que cada bloco foi sorteado.

## 4. Histórico: sorteios anulados

O período de referência foi redefinido três vezes, sempre porque a fonte da listagem não cobria todos os blocos. Nenhuma redefinição aconteceu depois de um sorteio de torneios, e nenhum ROI tinha sido consultado.

| # | Período | $B$ | Semente | Blocos sorteados | Motivo da anulação |
|---|---|---|---|---|---|
| 1 | 01/10 00:00 a 15/10 00:00 | 168 | 164363 | 5, 72, 100, 152, 158, 162 | O lobby do PokerStars não mostra torneios de 01/10 a 10/10; os blocos 5, 72 e 100 ficavam sem listagem. |
| 2 | 11/10 00:00 a 21/10 00:00 | 120 | 675598 | 17, 51, 56, 94, 103, 106 | Semente gerada ao acaso depois do sorteio 1; anulado minutos depois para manter a semente registrada antes de tudo. |
| 3 | 11/10 00:00 a 21/10 00:00 | 120 | 164363 | 30, 34, 63, 100, 105, 109 | O lobby só mostra parte dos torneios encerrados (em 13/10, só 9 no dia inteiro). A listagem completa (SharkScope) só existe a partir de 17/10 18:24, então os blocos 30, 34 e 63 ficavam sem listagem completa. A listagem parcial de 13/10, feita pelo lobby, foi descartada. |
| 4 | **17/10 20:00 a 21/10 00:00** | **38** | **164363** | **5, 8, 24, 30, 34, 36** | Sorteio oficial (§3). |

**Por que manter a semente:** a semente 164363 foi registrada antes de qualquer resultado. As mudanças de período vieram de limitações da fonte, e não dos blocos sorteados. Mantê-la evita qualquer suspeita de que ela foi escolhida depois de ver um resultado. Os números de bloco 30 e 34 se repetem entre os sorteios 3 e 4 porque a semente é a mesma, mas eles se referem a horários diferentes, já que as molduras são diferentes.

**Por que o período começa às 20:00 de 17/10:** a janela do SharkScope começa em 17/10 18:24. O período começa no primeiro início de bloco de 2 h dentro dela, e ficam de fora só 1 h 36 min. O fim, em 21/10 00:00, deixa tempo para consultar os ROIs e analisar até 23/10.

**Registro no log:** o [log](../data/raw/sharkscope/log_coleta.csv) traz cada sorteio e cada anulação. A anulação do sorteio 1 foi registrada 40 s depois do sorteio 2, porque a primeira tentativa de registro falhou. O log só recebe linhas novas, por isso os horários foram mantidos como estão. O resultado do sorteio 1 também está no histórico do Git (commit `f52a291`).

## 5. Observações

- **Janela móvel do SharkScope.** Em 19/10/2026 às 23:24, a busca de torneios do SharkScope começava em 17/10 18:24, cerca de 53 h antes. Se a janela andar com o tempo, cada bloco precisa ser listado, e ter os inscritos dos torneios sorteados copiados, antes de sair dela. Com ~53 h, os prazos aproximados são:

  | Bloco | Pode ser listado a partir de (fim do bloco) | Sai da janela por volta de |
  |---|---|---|
  | 5 | já | 20/10 09:00 |
  | 8 | já | 20/10 15:00 |
  | 24 | já | 21/10 23:00 |
  | 30 | 20/10 08:00 | 22/10 11:00 |
  | 34 | 20/10 16:00 | 22/10 19:00 |
  | 36 | 20/10 20:00 | 22/10 23:00 |

- **Coleta em lotes.** O sorteio de torneios e o de jogadores usam uma semente derivada por célula (bloco, estrato) e por torneio ([`R/sorteio.R`](../R/sorteio.R)). Assim, dá para sortear os blocos 5 e 8 primeiro e os outros depois, com a mesma semente, sem mudar o que já foi sorteado.
- **Fuso horário.** Os blocos foram definidos no horário de Brasília. Se o SharkScope mostrar os horários em outro fuso, converta antes de decidir se um torneio pertence ou não a um bloco.
- **Implementação em R.** A [§12 da Metodologia](Metodologia.md#12-implementação-de-referência-python) traz uma implementação de referência em Python. Com a mesma semente, o `numpy` sorteia blocos diferentes dos que o R sorteia. O sorteio oficial do projeto é o deste documento, feito em R.
- **Local dos arquivos.** Os arquivos de sorteio e o log ficam em `data/raw/sharkscope/`, junto com os demais arquivos da coleta de campo.
- **Composição da amostra.** No sorteio, dois blocos caem no domingo (5 e 8), um na segunda e três na terça. Depois da perda dos blocos 34 e 36 (§7), fica um bloco na terça (30). Dois dos quatro blocos efetivos estão de madrugada ou no início da manhã (5 e 30).

## 6. Andamento da Fase 1

Situação em 22/10/2026 ([log](../data/raw/sharkscope/log_coleta.csv); torneios sorteados em [`fase1_torneios_sorteados.md`](fase1_torneios_sorteados.md)):

| Bloco | Listado | Torneios elegíveis | Torneios sorteados | Top 10 anotado | Nicknames das posições sorteadas |
|---|---|---:|---:|---|---|
| 5 | 19/10 | 18 | 6 + 2 extras (22/10) | sim (20/10); extras pendentes | sim (20/10); extras pendentes |
| 8 | 19/10 | 21 | 6 + 2 extras (22/10) | sim (20/10); extras pendentes | sim (20/10); extras pendentes |
| 24 | 19/10 | 27 | 6 + 2 extras (23/10) | sim (20/10); extras pendentes | sim (20/10); extras pendentes |
| 30 | 20/10 | 17 | 6 + 2 extras (23/10) | sim (20/10); extras pendentes | sim (20/10); extras pendentes |
| 34 | perdido (§7) | — | — | — | — |
| 36 | perdido (§7) | — | — | — | — |

A amostra de torneios era de 24 (4 blocos × 3 estratos × 2). Pelo cálculo de $n$ ([Metodologia §5.1](Metodologia.md#51-cálculo-do-tamanho-da-amostra)), as 5 posições sorteadas de cada torneio passam a ser todas titulares ($`m_k = 5`$, sem reservas): 120 posições, das quais 6 são "Anônimo" (já marcadas como não resposta).

Em 22/10, depois da primeira rodada de consultas (20 respondentes em 51), três células ficaram com menos de 2 torneios com $`m_k \ge 2`$, e receberam torneios extras da mesma permutação ([ADR-011](../.ai/modelagem.md)): bloco 5 low (4039583266), bloco 5 micro (4039582664) e bloco 8 low (4039582706 e 4039581466). Em 23/10, com as 120 posições originais consultadas (49 respondentes), mais três células ficaram abaixo do mínimo e receberam extras: bloco 24 micro (4040085450 e 4040093364), bloco 30 low (4040087687) e bloco 30 micro (4040092069, o último torneio da célula; se falhar, a célula é colapsada com o low do bloco 30). A amostra passa a 32 torneios e 160 posições. O top 10 e os nicknames das posições dos 8 extras ainda não foram anotados.

Próximo passo: conferir se a lista de resultados dos torneios extras abre pelo ID no SharkScope (a busca dos quatro blocos já saiu da janela), anotar os nicknames e consultar as posições ainda em branco de [`coleta_jogadores.csv`](../data/raw/sharkscope/coleta_jogadores.csv) (cota de 140 por dia), anotando `roi`, `lucro` e `n_jogos_dia` em todas.

## 7. Perda dos blocos 34 e 36

Em 22/10/2026 os blocos 34 (20/10 14:00–16:00) e 36 (20/10 18:00–20:00) já não podiam ser listados: o custo de busca do SharkScope não alcança mais esses horários, mesmo usando toda a cota de buscas da conta.

Nesse dia foi feita uma listagem de 16:00–17:48 e de 20:00–21:57 de 20/10, porque a coluna "Pode ser listado a partir de" da §5 (o fim de cada bloco) foi lida como o início do intervalo a listar. Esses horários são dos blocos 35 e 37, que não foram sorteados. A listagem foi descartada e não entrou em [`listagem_torneios.csv`](../data/raw/sharkscope/listagem_torneios.csv).

**Decisão:** os blocos 34 e 36 são tratados como não resposta de UPA ([ADR-008](../.ai/modelagem.md#adr-008-perda-dos-blocos-34-e-36-não-resposta-de-upa)).

- A estimação usa os $b = 4$ blocos listados (5, 8, 24 e 30), com peso do 1º estágio $B/b = 38/4 = 9{,}5$ e variância entre blocos com 3 graus de liberdade.
- Não há substituição. Usar os blocos 35 e 37, que já estavam listados, seria uma troca escolhida, não sorteada, e a probabilidade de inclusão deixaria de ser conhecida. Um sorteio de reposição também não resolve, porque só os blocos 35, 37 e 38 ainda podiam ser listados.
- O período não é redefinido: os torneios e os jogadores dos outros quatro blocos já foram sorteados.

**Hipótese e ressalva:** a perda veio do acesso à fonte e não tem relação com o ROI dos jogadores, então os 4 blocos restantes são tratados como uma AAS de 4 entre os 38. Mesmo assim, os dois blocos perdidos são de terça à tarde e à noite, e o horário de dia útil depois das 14h fica representado só pelo bloco 24 (segunda, 18:00–20:00). Isso precisa ser discutido no relatório.

O evento está registrado no [log](../data/raw/sharkscope/log_coleta.csv) (`perda_upa`). O [`blocos_sorteados.csv`](../data/raw/sharkscope/blocos_sorteados.csv) continua com os 6 blocos, porque é o registro do sorteio, e marca a perda nas colunas `situacao` (`efetivo` ou `perdido`) e `b_efetivo` (4). A coluna `n_torneios_sorteados` traz os torneios sorteados em cada bloco, já com os extras do ADR-011.
