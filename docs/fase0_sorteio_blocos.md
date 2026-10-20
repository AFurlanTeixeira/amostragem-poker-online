# Fase 0 — Sorteio dos blocos de tempo

Registro da execução da Fase 0 do protocolo de coleta ([`Metodologia.md` §6](Metodologia.md#6-protocolo-de-coleta)): sorteio das unidades primárias de amostragem (UPA) do estágio temporal.

Data de execução: 19/10/2026

---

## 1. Parâmetros

| Parâmetro | Valor |
|---|---|
| Período de referência | 11/10/2026 00:00 a 21/10/2026 00:00 (10 dias corridos) |
| Duração do bloco | 2 h |
| Fuso horário | `America/Sao_Paulo` (horário de Brasília, UTC−3, sem horário de verão) |
| $B$ (blocos na moldura) | 120 = 10 dias × 12 blocos |
| $b$ (blocos sorteados) | 6 |
| Plano | AAS sem reposição (AASs) |
| Semente | 164363 |
| Probabilidade de inclusão de cada bloco | $b/B = 6/120 = 0{,}05$ |
| Peso do 1º estágio | $B/b = 20$ |

## 2. Procedimento

1. **Moldura:** a função `gerar_blocos()` ([`R/sorteio.R`](../R/sorteio.R)) gera os 120 blocos consecutivos de 2 h, numerados por `bloco_id` de 1 a 120 em ordem cronológica. O bloco 1 começa em 11/10/2026 00:00, e o bloco 120 termina em 21/10/2026 00:00.
2. **Sorteio:** a função `sortear_blocos()` sorteia 6 blocos distintos com `sample.int()` do R, usando a semente acima. O sorteio não altera o estado global do gerador de números aleatórios. A semente é a mesma registrada antes do primeiro sorteio (ver §4).
3. **Registro:** o resultado foi salvo em [`data/raw/sharkscope/blocos_sorteados.csv`](../data/raw/sharkscope/blocos_sorteados.csv), e o evento foi registrado em [`data/raw/sharkscope/log_coleta.csv`](../data/raw/sharkscope/log_coleta.csv).

Para reproduzir o sorteio:

```bash
Rscript scripts/sortear_amostra.R blocos --n-blocos 6 --seed 164363
```

As opções `--inicio`, `--dias`, `--horas-bloco` e `--fuso` têm como padrão os valores da tabela acima.

## 3. Resultado

| Ordem do sorteio | `bloco_id` | Início (Brasília) | Fim (Brasília) | Início (UTC) | Dia da semana |
|---|---|---|---|---|---|
| 3 | 30 | 13/10/2026 10:00 | 13/10/2026 12:00 | 13/10 13:00 | terça |
| 1 | 34 | 13/10/2026 18:00 | 13/10/2026 20:00 | 13/10 21:00 | terça |
| 6 | 63 | 16/10/2026 04:00 | 16/10/2026 06:00 | 16/10 07:00 | sexta |
| 4 | 100 | 19/10/2026 06:00 | 19/10/2026 08:00 | 19/10 09:00 | segunda |
| 2 | 105 | 19/10/2026 16:00 | 19/10/2026 18:00 | 19/10 19:00 | segunda |
| 5 | 109 | 20/10/2026 00:00 | 20/10/2026 02:00 | 20/10 03:00 | terça |

A tabela está em ordem cronológica. A coluna "Ordem do sorteio" indica a ordem em que cada bloco foi sorteado.

## 4. Sorteio anulado (período de 01/10 a 14/10/2026)

O primeiro sorteio desta fase usou o período de 01/10/2026 00:00 a 15/10/2026 00:00 ($B = 168$, semente 164363). Ele foi anulado em 19/10/2026, **antes da Fase 1**, ou seja, antes de qualquer torneio ser listado.

**Motivo:** o lobby do PokerStars mostra torneios de 21/09 a 30/09/2026 e de 11/10/2026 em diante, mas nenhum de 01/10 a 10/10/2026. Três dos seis blocos sorteados caíam nesse intervalo e não poderiam ser listados:

| `bloco_id` | Início (Brasília) | Situação |
|---|---|---|
| 5 | 01/10/2026 08:00 | sem listagem |
| 72 | 06/10/2026 22:00 | sem listagem |
| 100 | 09/10/2026 06:00 | sem listagem |
| 152 | 13/10/2026 14:00 | com listagem |
| 158 | 14/10/2026 02:00 | com listagem |
| 162 | 14/10/2026 10:00 | com listagem |

Descartar os três blocos sem listagem e ficar com os outros três quebraria a probabilidade de inclusão $b/B$. Na prática, a população passaria a ser só 11/10 a 14/10, sem que isso estivesse no desenho. Por isso o período de referência foi redefinido para um intervalo em que todos os blocos podem ser listados, e o sorteio foi refeito na nova moldura com a **mesma semente**.

**Por que não usar 21/09 a 30/09:** esses torneios estão dentro da janela do ROI (01/10/2025 a 30/09/2026, [Metodologia §2.4](Metodologia.md#24-variáveis-de-interesse)). Se entrassem na população, o resultado de cada torneio sorteado entraria no próprio ROI medido. A partir de 11/10, população e janela do ROI ficam separadas.

**Por que a mesma semente:** a semente 164363 foi registrada antes de qualquer resultado. O período mudou por um motivo externo (falta de listagem), e não por causa dos blocos sorteados. Manter a semente evita qualquer suspeita de que ela foi escolhida depois de ver o primeiro resultado.

**Registro no log:** o [log](../data/raw/sharkscope/log_coleta.csv) tem, em ordem:

1. o sorteio original (01/10 a 14/10, semente 164363);
2. um sorteio intermediário no novo período com a semente 675598, gerada ao acaso;
3. a anulação do sorteio original, registrada 40 s depois do sorteio intermediário porque a primeira tentativa de registro falhou;
4. a anulação do sorteio intermediário, para voltar à semente 164363;
5. o sorteio oficial (11/10 a 20/10, semente 164363).

O sorteio intermediário (blocos 17, 51, 56, 94, 103 e 106) foi anulado minutos depois, também antes da Fase 1. O log só recebe linhas novas, por isso os horários foram mantidos como estão. O resultado do sorteio original continua no histórico do Git (commit `f52a291`).

## 5. Observações

- **Fuso horário.** Os blocos foram definidos no horário de Brasília. O arquivo de saída também traz o início de cada bloco em UTC (`inicio_utc`). Na Fase 1, se o lobby do PokerStars ou o SharkScope mostrarem os horários em outro fuso (por exemplo, o horário da costa leste dos EUA), precisamos converter os horários para o fuso dos blocos antes de decidir se um torneio pertence ou não a um bloco.
- **Implementação em R.** A [§12 da Metodologia](Metodologia.md#12-implementação-de-referência-python) traz uma implementação de referência em Python. Com a mesma semente, o `numpy` sorteia blocos diferentes dos que o R sorteia. O sorteio oficial do projeto é o deste documento, feito em R.
- **Local dos arquivos.** A Metodologia (§6 e §13) indica `data/raw/` como pasta dos arquivos de sorteio e do log. Eles foram salvos em `data/raw/sharkscope/`, junto com os demais arquivos da coleta de campo.
- **Composição da amostra.** Nenhum dos seis blocos cai em fim de semana, e três estão de madrugada ou no início da manhã (blocos 63, 100 e 109). Com $b = 6$, essa composição é uma consequência possível da AASs.
- **Blocos e data de execução.** O bloco 109 (20/10 00:00–02:00) ainda não tinha acontecido quando o sorteio foi feito (19/10, por volta das 22:15). Isso não muda o desenho, porque a moldura foi definida antes, mas o bloco só pode ser listado depois que terminar.

## 6. Próximo passo (Fase 1)

Listar os torneios dos blocos o quanto antes, começando pelos blocos 30 e 34 (13/10), que são os mais antigos e os primeiros a correr risco de sair do histórico do lobby. O bloco 109 só pode ser listado depois de 20/10 às 02:00. Se a aba *Concluídos* não mostrar algum bloco, usaremos a busca de torneios do SharkScope ou a agenda oficial do PokerStars e registraremos a fonte usada em cada bloco ([Metodologia §6, passo 3](Metodologia.md#fase-1--listagem-dos-torneios-dentro-dos-blocos-sorteados)).
