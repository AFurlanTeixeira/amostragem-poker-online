# Fase 0 — Sorteio dos blocos de tempo

Registro da execução da Fase 0 do protocolo de coleta ([`Metodologia.md` §6](Metodologia.md#6-protocolo-de-coleta)): sorteio das unidades primárias de amostragem (UPA) do estágio temporal.

Data de execução: 19/10/2026

---

## 1. Parâmetros

| Parâmetro | Valor |
|---|---|
| Período de referência | 01/10/2026 00:00 a 15/10/2026 00:00 (14 dias corridos) |
| Duração do bloco | 2 h |
| Fuso horário | `America/Sao_Paulo` (horário de Brasília, UTC−3, sem horário de verão) |
| $B$ (blocos na moldura) | 168 = 14 dias × 12 blocos |
| $b$ (blocos sorteados) | 6 |
| Plano | AAS sem reposição (AASs) |
| Semente | 164363 |
| Probabilidade de inclusão de cada bloco | $b/B = 6/168 \approx 0{,}0357$ |
| Peso do 1º estágio | $B/b = 28$ |

## 2. Procedimento

1. **Moldura:** a função `gerar_blocos()` ([`R/sorteio.R`](../R/sorteio.R)) gera os 168 blocos consecutivos de 2 h, numerados por `bloco_id` de 1 a 168 em ordem cronológica. O bloco 1 começa em 01/10/2026 00:00, e o bloco 168 termina em 15/10/2026 00:00.
2. **Sorteio:** a função `sortear_blocos()` sorteia 6 blocos distintos com `sample.int()` do R, usando a semente acima. O sorteio não altera o estado global do gerador de números aleatórios.
3. **Registro:** o resultado foi salvo em [`data/raw/sharkscope/blocos_sorteados.csv`](../data/raw/sharkscope/blocos_sorteados.csv), e o evento foi registrado em [`data/raw/sharkscope/log_coleta.csv`](../data/raw/sharkscope/log_coleta.csv).

Para reproduzir o sorteio:

```bash
Rscript scripts/sortear_amostra.R blocos --n-blocos 6 --seed 164363
```

As opções `--inicio`, `--dias`, `--horas-bloco` e `--fuso` têm como padrão os valores da tabela acima.

## 3. Resultado

| Ordem do sorteio | `bloco_id` | Início (Brasília) | Fim (Brasília) | Início (UTC) | Dia da semana |
|---|---|---|---|---|---|
| 6 | 5 | 01/10/2026 08:00 | 01/10/2026 10:00 | 01/10 11:00 | quinta |
| 4 | 72 | 06/10/2026 22:00 | 07/10/2026 00:00 | 07/10 01:00 | terça |
| 3 | 100 | 09/10/2026 06:00 | 09/10/2026 08:00 | 09/10 09:00 | sexta |
| 5 | 152 | 13/10/2026 14:00 | 13/10/2026 16:00 | 13/10 17:00 | terça |
| 2 | 158 | 14/10/2026 02:00 | 14/10/2026 04:00 | 14/10 05:00 | quarta |
| 1 | 162 | 14/10/2026 10:00 | 14/10/2026 12:00 | 14/10 13:00 | quarta |

A tabela está em ordem cronológica. A coluna "Ordem do sorteio" indica a ordem em que cada bloco foi sorteado.

## 4. Observações

- **Fuso horário.** Os blocos foram definidos no horário de Brasília. O arquivo de saída também traz o início de cada bloco em UTC (`inicio_utc`). Na Fase 1, se o lobby do PokerStars ou o SharkScope mostrarem os horários em outro fuso (por exemplo, o horário da costa leste dos EUA), precisamos converter os horários para o fuso dos blocos antes de decidir se um torneio pertence ou não a um bloco.
- **Implementação em R.** A [§12 da Metodologia](Metodologia.md#12-implementação-de-referência-python) traz uma implementação de referência em Python. Com a mesma semente, o `numpy` sorteia blocos diferentes dos que o R sorteia. O sorteio oficial do projeto é o deste documento, feito em R.
- **Local dos arquivos.** A Metodologia (§6 e §13) indica `data/raw/` como pasta dos arquivos de sorteio e do log. Eles foram salvos em `data/raw/sharkscope/`, junto com os demais arquivos da coleta de campo.
- **Composição da amostra.** Nenhum dos blocos sorteados cai em fim de semana, e três deles estão de madrugada ou no início da manhã (horário de Brasília). Isso é uma consequência possível da AASs com $b = 6$. Se for adotada a variante com estratificação temporal (dia útil × fim de semana; [Metodologia §3](Metodologia.md#3-por-que-um-estágio-temporal)), devemos refazer o sorteio **antes** da Fase 1, e registrar a mudança no log.

## 5. Próximo passo (Fase 1)

Antes de listar os torneios, verificar se a aba *Concluídos* do lobby do PokerStars ainda mostra torneios de 01/10/2026 (bloco 5). Se não mostrar, usaremos a busca de torneios do SharkScope ou a agenda oficial do PokerStars e registraremos a fonte usada em cada bloco ([Metodologia §6, passo 3](Metodologia.md#fase-1--listagem-dos-torneios-dentro-dos-blocos-sorteados)).
