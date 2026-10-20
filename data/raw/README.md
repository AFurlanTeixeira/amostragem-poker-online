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
| `moldura_torneios.csv` | Todos os torneios do período de referência: `estrato`, `torneio_id`, `buy_in`, `n_inscritos` | Montado à mão a partir do lobby |
| `torneios_sorteados.csv` | Torneios do 1º estágio | `scripts/sortear_amostra.R torneios` |
| `inscritos.csv` | Inscritos dos torneios sorteados: `torneio_id`, `nickname` | Montado à mão |
| `jogadores_sorteados.csv` | Titulares e reservas do 2º estágio | `scripts/sortear_amostra.R jogadores` |
| `coleta_jogadores.csv` | Resultado de cada consulta ao SharkScope | Preenchido à mão durante a coleta |

Os arquivos `*_modelo.csv` mostram o cabeçalho esperado de cada planilha. Na coleta:

- `respondeu = FALSE` marca um perfil privado. Nesse caso, consulte o próximo jogador da reserva do **mesmo** torneio.
- `roi` vai em %; `lucro`, em US$.
