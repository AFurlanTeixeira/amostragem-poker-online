# 🎲 Comparação de Planos Amostrais no Poker Online

### 📌 Sobre o Projeto

Projeto de **Amostragem** (Estatística, Unicamp, 2026). Compara dois tipos de plano para estimar o **ROI médio** e a **proporção de jogadores lucrativos** em torneios de poker online:

1. **Amostragem direta de elementos** (AAS e AAS estratificada), simulada por **Monte Carlo** sobre um dataset do Kaggle tratado como população conhecida.
2. **Amostragem estratificada em dois estágios**, aplicada em campo no **SharkScope**: estratos por faixa de buy-in, torneios como unidades primárias e jogadores como unidades secundárias.

O plano completo, com fórmulas e referências, está em [`docs/plano_projeto.md`](docs/plano_projeto.md).

- **Entregáveis:** relatório técnico e apresentação em slides, num ciclo de 20 dias.
- **Referências principais:** Thompson (2012), *Sampling*, 3ª ed.; Bolfarine & Bussab, *Elementos de Amostragem*.

---

### 📄 Dados

| Fonte | Papel | Onde |
|---|---|---|
| [Kaggle: *Poker Tournament Survival — Skill vs. Variance*](https://www.kaggle.com/datasets/sergionefedov/poker-tournament-survivorship) | População conhecida (45.000 jogadores, 17 colunas, dados sintéticos) para as simulações de AAS e AAS estratificada | `data/raw/kaggle/` (fora do git) |
| SharkScope | Coleta de campo do plano em dois estágios (de 5 a 10 consultas por dia; n ≈ 50 a 100) | [`data/raw/sharkscope/`](data/raw/sharkscope) (versionado) |

Detalhes, dicionário de dados e cabeçalhos das planilhas de campo: [`data/raw/README.md`](data/raw/README.md).

---

## 🔍 Profiling do Dataset do Kaggle

O arquivo `data/raw/kaggle/poker_tournament_survival.csv`:

- **Tamanho:** 45.000 jogadores × 17 colunas; nenhum valor ausente; `player_id` único.
- **Natureza:** dados **sintéticos**. O dicionário descreve `skill` como a "vantagem verdadeira de longo prazo", uma variável latente que não é observável em dados reais.
- **Unidade:** o jogador, com o histórico agregado de 10 a 1.567 torneios (mediana de 111). É análoga a um perfil do SharkScope. **Não há ID de torneio**, então o plano em dois estágios não pode ser simulado neste dataset.
- **Parâmetros verdadeiros:** ROI médio $\mu = -31{,}88\%$ (mediana de −34%, DP de 45,96 p.p.); proporção de lucrativos $P = 0{,}1939$; 50,0% quebraram a banca (`went_broke`).
- **Distribuição do ROI:** limitada entre −100% e +400%, com cauda direita longa (P99 ≈ 109%). O IC normal funciona bem com n = 60 (cobertura de 94% a 95% nas simulações).
- **Estratos por buy-in** (`avg_buyin`, mesmas faixas do campo): micro 1.060 (2,4%), low 14.652 (32,6%), mid_high 29.288 (65,1%). O ROI médio é praticamente igual nas três faixas (−31,9%, −32,4% e −31,6%). A correlação entre ROI e buy-in é de 0,0006.

### Resultados preliminares (n = 60, 5.000 réplicas, seed = 42)

| Estratificação | Parâmetro | EPA empírico (estratificada / AAS) | Cobertura do IC 95% (AAS / estratificada) |
|---|---|---|---|
| Buy-in (igual ao campo) | ROI | 0,98 | 94,4% / 94,4% |
| Buy-in (igual ao campo) | P | 0,99 | 94,3% / 94,0% |
| Quartis de `skill` (didático) | ROI | 0,95 | 95,0% / 95,1% |
| Quartis de `skill` (didático) | P | 0,94 | 94,6% / 94,8% |

Neste dataset, estratificar por buy-in praticamente não reduz a variância, porque o ROI não varia entre as faixas. Estratificar por `skill` ganha um pouco (correlação ROI–skill de 0,23, ou seja, EPA ≈ 1 − R² ≈ 0,95). Mas `skill` não é observável em campo.

---

### 🎯 Perguntas a Responder

1. Qual o ROI médio por jogador ($\mu$) e a proporção de jogadores lucrativos ($P$), com IC de 95%?
2. Quanto da variância vem da variação **entre torneios** e quanto vem da variação **dentro dos torneios**?
3. Qual o **Efeito do Planejamento (EPA/DEFF)** do plano em dois estágios e a correlação intraclasse $\rho_{int}$ implícita?
4. No Kaggle, quanto a estratificação ganha em relação à AAS (viés, EQM, cobertura do IC)?
5. Qual a taxa de não resposta (perfis privados) e qual o seu possível impacto?

---

## 🧮 Arquitetura

```
data/raw/kaggle/*.csv                       data/raw/sharkscope/moldura_torneios.csv
        │                                                │
        ▼                                                ▼
 carregar_populacao_kaggle()              sortear_torneios()   ── 1º estágio (UPA)
        │                                                │
        ▼                                                ▼
 simular_planos()  ── AAS / AAS estrat.   sortear_jogadores()  ── 2º estágio (USA) + reserva
   (Monte Carlo, n_rep réplicas)                         │
        │                                                ▼
        ▼                                     coleta no SharkScope (5 a 10/dia)
 resumir_simulacao()                                     │
   viés · EQM · cobertura · EPA empírico                 ▼
        │                              estimar_media_dois_estagios() · calcular_epa()
        └──────────────► comparação no relatório ◄───────┘
```

Decisões de modelagem em formato ADR: [`.ai/modelagem.md`](.ai/modelagem.md).

---

## 🛠️ Configuração do Projeto

### Pré-requisitos

| Ferramenta | Versão mínima |
|-----------|--------------|
| R | 4.3 |
| Pacotes R | `optparse`, `testthat` (opcional: `rmarkdown`, `lintr`) |
| CLI do Kaggle | só para baixar o dataset (`pip install kaggle`) |

### Instalação

```r
install.packages(c("optparse", "testthat", "rmarkdown", "lintr"))
```

### Variáveis de ambiente (opcional)

```bash
cp .env.example .env   # semente, caminho e estratificação do Kaggle, tamanhos de amostra
```

---

## 🏡 Rodando localmente

```bash
# 1. Baixar o dataset do Kaggle
bash scripts/baixar_kaggle.sh

# 2. Monte Carlo no Kaggle (AAS vs. AAS estratificada)
Rscript scripts/simular_kaggle.R --estratificar-por buyin --n 60 --n-rep 5000 --seed 42

# 3. Sorteio de campo
Rscript scripts/sortear_amostra.R torneios  --n-por-estrato 5 --seed 42
Rscript scripts/sortear_amostra.R jogadores --m-por-torneio 4 --n-reserva 4 --seed 42

# 4. Estimação a partir da coleta
Rscript scripts/estimar_campo.R --metodo auto
```

### Relatório

```r
rmarkdown::render("docs/relatorio.Rmd")   # gera docs/relatorio.html
```

### Testes

```bash
Rscript -e 'testthat::test_dir("tests/testthat")'
```

Os testes dos estimadores reproduzem os exemplos resolvidos do Thompson (§11.2–11.3 e §13.1), o que valida as fórmulas implementadas.

---

## 💾 Estrutura de Pastas

```
data/
  raw/
    kaggle/                       # Dataset do Kaggle (fora do git)
    sharkscope/                   # Moldura, sorteios e coleta de campo (versionados)
  processed/                      # Resultados gerados (fora do git)
docs/
  plano_projeto.md                # Plano de projeto v2 (fórmulas + referências)
  referencias.md                  # Mapa fórmula → livro/seção
  relatorio.Rmd                   # Relatório executável (esqueleto)
scripts/
  baixar_kaggle.sh                # Download do dataset
  simular_kaggle.R                # Monte Carlo de AAS / AAS estratificada
  sortear_amostra.R               # Sorteio do 1º e 2º estágios
  estimar_campo.R                 # Estimação em dois estágios, IC, EPA
R/
  dados.R                         # Leitura e validação das fontes
  sorteio.R                       # Sorteio estratificado em dois estágios + reserva
  estimadores_aas.R               # AAS e AAS estratificada (Thompson cap. 11)
  estimadores_dois_estagios.R     # Dois estágios, razão, EPA (Thompson cap. 13; Bolfarine cap. 8)
  simulacao_kaggle.R              # Monte Carlo sobre a população do Kaggle
tests/
  testthat/                       # Testes unitários (testthat)
```

## 🤖 Contexto para IAs

| Arquivo | Descrição |
|---------|-----------|
| [CLAUDE.md](CLAUDE.md) | Guia rápido para o Claude Code |
| [.ai/contexto.md](.ai/contexto.md) | Visão geral: stack, fluxo e índice |
| [.ai/padroes-codigo.md](.ai/padroes-codigo.md) | Padrões de R e de testes |
| [.ai/modelagem.md](.ai/modelagem.md) | Decisões estatísticas (ADRs) |

---

### ✅ Checklist de Entregas

[x] Plano de projeto revisado (v2) com fórmulas e referências

[x] Estimadores implementados e validados contra os exemplos do Thompson

[x] Dataset do Kaggle carregado e perfilado (colunas e natureza sintética confirmadas; licença pendente)

[x] Simulações de Monte Carlo no Kaggle (AAS vs. AAS estratificada por buy-in e por skill)

[ ] Moldura de torneios do período de referência + sorteio do 1º estágio

[ ] Sorteio do 2º estágio + coleta no SharkScope

[ ] Estimação em dois estágios, IC 95%, EPA e $\rho_{int}$

[ ] Relatório técnico

[ ] Slides
