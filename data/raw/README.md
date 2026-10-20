# Dados brutos

Dado bruto não é editado nem transformado aqui: as transformações ficam em `R/`.

## `kaggle/`: população conhecida

- **Dataset:** [Poker Tournament Survival — Skill vs. Variance](https://www.kaggle.com/datasets/sergionefedov/poker-tournament-survivorship) (autor: `sergionefedov`).
- **Arquivos:** `poker_tournament_survival.csv` (45.000 linhas × 17 colunas) e `data_dictionary_poker.csv`.
- **Como obter:** baixe pelo Kaggle e coloque os dois CSVs nesta pasta, ou rode `bash scripts/baixar_kaggle.sh` (requer a CLI do Kaggle e o token em `~/.kaggle/kaggle.json`).
- **Por que fica fora do git:** a licença não aparece na página do dataset. Confirme antes de redistribuir.
- **Natureza:** dados **sintéticos**. A coluna `skill` é a "vantagem verdadeira de longo prazo", uma variável latente que só existe numa simulação.
- **Limitação:** não há ID de torneio, então o plano em dois estágios não pode ser simulado aqui; só a AAS e a AAS estratificada.

### Dicionário (colunas usadas pelo projeto em negrito)

| Coluna | Tipo | Descrição |
|---|---|---|
| **`player_id`** | texto | ID único do jogador |
| **`skill`** | real (0–10) | Vantagem verdadeira de longo prazo (latente) → estratificação didática por quartis |
| `bankroll_mgmt` | real (0–10) | Disciplina de gestão de banca |
| `tilt_control` | real (0–10) | Controle emocional |
| `study_hours_week` | real | Horas de estudo por semana |
| `tournaments_played` | inteiro | Torneios jogados na amostra (10 a 1.567) |
| `avg_field_size` | inteiro | Tamanho médio do field |
| **`avg_buyin`** | real (US$) | Buy-in médio → estratificação por faixa (mesma do campo) |
| `bankroll_buyins` | inteiro | Banca inicial, em buy-ins |
| `itm_rate` | real (%) | Taxa de premiação (ITM) |
| `final_table_rate` | real (%) | Taxa de mesa final |
| `win_rate` | real (%) | Taxa de vitória |
| `biggest_cash_x` | real | Maior prêmio, em buy-ins |
| `final_bankroll_bi` | real | Banca final, em buy-ins (0 se quebrou) |
| **`realized_roi`** | real (%) | ROI realizado → variável `roi` |
| **`went_broke`** | 0/1 | 1 se a banca chegou a zero |
| **`profitable`** | 0/1 | 1 se ROI > 0 → variável `lucrativo` |

## `sharkscope/`: coleta de campo (versionada)

| Arquivo | Conteúdo | Quem gera |
|---|---|---|
| `blocos_sorteados.csv` | Blocos de 2 h sorteados na Fase 0 (estágio temporal), com fuso, `B`, `b` e `seed` | `scripts/sortear_amostra.R blocos` |
| `log_coleta.csv` | Um evento por linha: sorteios, substituições e não respostas | Scripts de sorteio e anotações à mão |
| `listagem_torneios.csv` | Fase 1: **todos** os torneios com início dentro dos blocos sorteados, inclusive os excluídos (ver abaixo) | Preenchido à mão a partir da busca de torneios do SharkScope |
| `torneios_sorteados.csv` | Torneios sorteados em cada (bloco, estrato), com `N_jh` e `n_jh` | `scripts/sortear_amostra.R torneios` |
| `jogadores_sorteados.csv` | 2º estágio: posições sorteadas na lista de resultados de cada torneio (2 titulares + 3 reservas, em `ordem`) | `scripts/sortear_amostra.R jogadores` |
| `coleta_jogadores.csv` | Resultado de cada consulta ao SharkScope | Preenchido à mão durante a coleta |
| `top10_torneios.csv` | Os 10 primeiros colocados de cada torneio sorteado, para comparação futura. **Fora do plano amostral**: não entra nos estimadores | Linhas criadas por `scripts/sortear_amostra.R top10`; `nickname` e `data_anotacao` preenchidos à mão |

Os arquivos `*_modelo.csv` mostram o cabeçalho esperado de cada planilha.

### `top10_torneios.csv`

Levantamento completo, sem sorteio: todo nome do top 10 que puder ser consultado entra na análise. O `nickname` é guardado como a fonte mostra, inclusive com o sufixo `[n]` que alguns trazem (ex.: `baradavid[2]`). Para consultar ou comparar jogadores, use o nome sem o sufixo.

- **Anônimo:** jogadores que aparecem como `Anônimo` (ou `Anônimo[n]`) não podem ser consultados nem distinguidos entre si, então ficam fora da análise.
- **Repetidos:** um mesmo jogador pode aparecer no top 10 de mais de um torneio. Não é erro; cada aparição é mantida.

Situação com os blocos 5, 8, 24 e 30 (24 torneios):

| | Linhas |
|---|---:|
| Total | 240 |
| `Anônimo` | 15 |
| Consultáveis | 225 |
| Jogadores distintos entre os consultáveis | 217 |

Os 8 jogadores que aparecem em dois torneios são: `baradavid` e `comistus` (4039581390 e 4038334524), `CrazySezya` (4039581390 e 4039581475), `judem96` e `JusuBoi` (4040087674 e 4040085499), `liova777` (4038334525 e 4040087659), `Mind_ze` (4040092095 e 4040093464) e `törski` (4040092085 e 4040085499).

Na lista de inscritos não se transcreve nada além das posições sorteadas. A posição é a da lista de resultados do torneio no SharkScope (1 = campeão), e vai de 1 a `M_k` (`n_inscritos`). Em cada torneio, siga a `ordem` de `jogadores_sorteados.csv`:

- Anote o `nickname` da posição em `coleta_jogadores.csv`, com a `ordem` e a `posicao`.
- Se a posição não existir na lista (a lista tem menos linhas que `M_k` por causa das re-entries) ou repetir um jogador já sorteado no torneio, pule para a próxima da ordem e registre o pulo em `log_coleta.csv`.

Na coleta:

- `respondeu = FALSE` marca um perfil privado. Nesse caso, consulte a próxima posição da reserva do **mesmo** torneio.
- `roi` vai em %; `lucro`, em US$.

### `listagem_torneios.csv` (Fase 1)

Copie `listagem_torneios_modelo.csv` para `listagem_torneios.csv` e preencha **uma linha por torneio** com início dentro de um dos blocos de `blocos_sorteados.csv` ([Metodologia §6, passos 3 e 4](../../docs/Metodologia.md#fase-1--listagem-dos-torneios-dentro-dos-blocos-sorteados)). Liste também os torneios que serão descartados (freerolls, buy-in abaixo de US\$ 1,00, satélites etc.), marcando o motivo em `motivo_exclusao`. Assim o número de descartados por bloco sai da própria planilha. O estrato e o $`N_{jh}`$ são calculados em `R/`, e não preenchidos à mão: `montar_moldura()` fica com os torneios elegíveis e classifica o estrato pelo `buy_in`. Não existe uma planilha de moldura separada.

| Coluna | Tipo | Como preencher |
|---|---|---|
| `bloco_id` | inteiro | `bloco_id` do bloco sorteado (5, 8, 24, 30, 34 ou 36) |
| `torneio_id` | texto | ID do torneio no PokerStars (sem `#`) |
| `nome` | texto | Nome do torneio como aparece na fonte |
| `inicio_fonte` | `AAAA-MM-DD HH:MM` | Horário de início **exatamente como a fonte mostra** |
| `fuso_fonte` | texto | Fuso do horário acima (ex.: `America/Sao_Paulo`, `America/New_York`) |
| `inicio_brasilia` | `AAAA-MM-DD HH:MM` | Início convertido para o horário de Brasília. Deve cair em `[inicio, fim)` do bloco |
| `tipo` | texto | `mtt`, `freeroll`, `satelite`, `spin`, `sng` ou `outro` |
| `buy_in` | real (US\$) | Buy-in **total** pago por entrada (prêmio + taxa), ex.: `5.50` para \$5 + \$0,50. Para torneios com bounty, inclui a parte do bounty |
| `n_entradas_fonte` | inteiro | Total de entradas mostrado pela fonte, **com re-entries**. É usado como $`M_k`$ (`n_inscritos`), por simplificação ([Metodologia §2.4](../../docs/Metodologia.md#24-variáveis-de-interesse)) |
| `status` | texto | `concluido`, `em_andamento` ou `cancelado` |
| `motivo_exclusao` | texto | Vazio se o torneio é elegível. Senão: `freeroll`, `buyin_abaixo_1`, `satelite`, `nao_mtt`, `cancelado` ou `poucos_inscritos` |
| `fonte` | texto | `sharkscope` (padrão) ou `agenda` (de onde veio a linha). O lobby do PokerStars não serve: mostra só parte dos torneios |
| `data_listagem` | `AAAA-MM-DD` | Dia em que a linha foi anotada |
| `observacao` | texto | Livre (ex.: dúvida de classificação, horário ambíguo) |

Regras:

- **Limite do bloco:** o intervalo é fechado no início e aberto no fim. Um torneio que começa às 12:00 pertence ao bloco 12:00–14:00, e não ao bloco 10:00–12:00.
- **Separador:** o arquivo usa vírgula como separador e ponto como decimal (`5.50`). Se um `nome` tiver vírgula, coloque-o entre aspas. No Excel em português, salve como "CSV UTF-8" e confira se ele não trocou as vírgulas por ponto e vírgula.
- **Moeda:** se aparecer um torneio com buy-in em outra moeda, converta para US\$ e explique a conversão em `observacao`.
- **Prazo:** a janela do SharkScope parece andar com o tempo (cerca de 53 h de histórico). Liste cada bloco, sorteie os torneios dele e anote os nicknames das posições sorteadas e o top 10 dos sorteados antes que ele saia da janela. Os prazos por bloco estão em [`docs/fase0_sorteio_blocos.md`](../../docs/fase0_sorteio_blocos.md) §5. Os sorteios podem ser feitos em lotes, com a mesma semente, que o resultado de um bloco não muda.
- **Bloco sem torneios disponíveis:** registre o fato em `log_coleta.csv`, com a fonte alternativa usada.

Exemplo de linha (dados fictícios):

```csv
bloco_id,torneio_id,nome,inicio_fonte,fuso_fonte,inicio_brasilia,tipo,buy_in,n_entradas_fonte,status,motivo_exclusao,fonte,data_listagem,observacao
8,3912345678,$5.50 NL Hold'em [Turbo],2026-10-18 09:15,America/New_York,2026-10-18 10:15,mtt,5.50,412,concluido,,sharkscope,2026-10-19,
```
