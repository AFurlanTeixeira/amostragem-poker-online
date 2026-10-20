# Metodologia — Amostragem em Múltiplos Estágios no Poker Online

> Comparação entre um plano amostral direto de elementos (dataset Kaggle) e um plano complexo com **estágio temporal, estratificação por buy-in e conglomerados** aplicado a torneios do PokerStars, com coleta de desempenho via SharkScope.

Autor: Arthur Agostinho — Estatística, Unicamp
Disciplina: Técnicas de Amostragem

---

## Sumário

1. [Motivação](#1-motivação)
2. [População, unidades e variáveis](#2-população-unidades-e-variáveis)
3. [Por que um estágio temporal](#3-por-que-um-estágio-temporal)
4. [Delineamento amostral](#4-delineamento-amostral)
5. [Tamanho e alocação da amostra](#5-tamanho-e-alocação-da-amostra)
6. [Protocolo de coleta](#6-protocolo-de-coleta)
7. [Estimadores](#7-estimadores)
8. [Estimação da variância](#8-estimação-da-variância)
9. [Efeito do planejamento (EPA/DEFF)](#9-efeito-do-planejamento-epadeff)
10. [Baseline: dataset Kaggle](#10-baseline-dataset-kaggle)
11. [Erros não amostrais](#11-erros-não-amostrais)
12. [Implementação de referência (Python)](#12-implementação-de-referência-python)
13. [Estrutura do repositório e dicionário de dados](#13-estrutura-do-repositório-e-dicionário-de-dados)
14. [Limitações e considerações éticas](#14-limitações-e-considerações-éticas)
15. [Referências](#15-referências)

---

## 1. Motivação

O objetivo é estimar o desempenho médio dos jogadores de torneios de poker online, medido pelo **ROI médio** ($\bar{Y}$), e a **proporção de jogadores lucrativos** ($P$). Também queremos quantificar quanto a estrutura de conglomerados (jogadores agrupados em torneios, e torneios agrupados no tempo) altera a precisão das estimativas, em comparação com uma amostra aleatória simples.

Duas restrições práticas definem o desenho:

- **Não existe uma moldura completa de torneios.** O PokerStars realiza centenas de milhares de torneios por ano e não publica uma lista com todos eles.
- **A coleta de desempenho é cara.** O SharkScope limita o número de consultas por dia (50 no plano pago usado no projeto), e o prazo de entrega deixa só alguns dias de coleta, então a amostra final fica perto de 70 a 100 jogadores.

Por isso o desenho evita depender de uma lista completa e concentra o esforço de coleta em poucos conglomerados.

---

## 2. População, unidades e variáveis

### 2.1 População-alvo

> Inscrições de jogadores em **torneios MTT regulares com buy-in de US\$ 1,00 ou mais** (excluindo freerolls, torneios abaixo de US\$ 1,00, Spin & Go, Sit & Go e torneios satélite assim como Cash Game) do **PokerStars.com**, com início entre **17/10/2026 20:00** e **21/10/2026 00:00** (76 h, horário de Brasília).
>
> O período é limitado pela fonte da listagem. O lobby do PokerStars só mostra parte dos torneios já encerrados (em 13/10/2026, apenas 9 no dia inteiro), então não serve como moldura. A busca de torneios do SharkScope mostra todos, mas só a partir de 17/10/2026 18:24. O período começa às 20:00 de 17/10, o primeiro início de bloco de 2 h dentro dessa janela, e termina antes do prazo da análise (23/10). Os períodos anteriores (01/10 a 14/10 e 11/10 a 20/10) foram abandonados antes de qualquer sorteio de torneios (ver [`fase0_sorteio_blocos.md`](fase0_sorteio_blocos.md)).
>
> Os torneios abaixo de US\$ 1,00 ficam fora pois têm comportamento atípico (muitos inscritos, na maioria jogadores recreativos, prêmios irrisórios e ROI pouco informativo). Eles também são **descartados na listagem** de cada bloco, antes do sorteio do 2º estágio.

Como a unidade elementar é a **inscrição** (o par jogador × torneio), um mesmo jogador pode aparecer mais de uma vez na população, em torneios diferentes. Isso é intencional: o parâmetro estimado é o ROI médio *por inscrição*, que pondera os jogadores pela frequência com que jogam.

**Re-entries:** dentro de um mesmo torneio, o jogador conta **uma única vez**, por mais entradas que tenha feito. O ROI do SharkScope é um atributo do jogador, e não da entrada; se cada entrada contasse como uma unidade, quem faz re-entry teria mais chance de ser sorteado e um mesmo valor de $y$ poderia aparecer duplicado no conglomerado. O número de entradas fica registrado como variável auxiliar (`n_entradas`). Na análise, discutimos a diferença em relação ao ROI médio *por jogador distinto* (ver [§14](#14-limitações-e-considerações-éticas)).

### 2.2 Hierarquia de unidades

| Nível | Unidade | Notação | Total na população | Na amostra |
|---|---|---|---|---|
| 1º estágio (UPA) | Bloco de tempo de 2 h | $j$ | $B$ | $b$ |
| Estratos (dentro do bloco) | Faixa de buy-in | $h = 1,\dots,H$ | — | — |
| 2º estágio (USA) | Torneio | $k$ | $`N_{jh}`$ | $`n_{jh}`$ |
| 3º estágio (UTA) | Jogador distinto inscrito no torneio | $i$ | $`M_k`$ | $`m_k`$ |

### 2.3 Estratos de buy-in

| Estrato | Faixa de buy-in |
|---|---|
| $h=1$ — Micro | US\$ 1,00 a 4,99 |
| $h=2$ — Low | US\$ 5,00 a 24,99 |
| $h=3$ — Mid/High | US\$ 25,00 ou mais |

### 2.4 Variáveis de interesse

| Variável | Definição | Fonte |
|---|---|---|
| $`y_{ki}`$ — ROI | *Total ROI* (%) do jogador no SharkScope na **janela fixa de 01/10/2025 a 30/09/2026**, considerando só o PokerStars | SharkScope |
| $`\ell_{ki}`$ — Lucro | *Profit* (US\$) no mesmo filtro | SharkScope |
| $`d_{ki}`$ — Lucrativo | $`d_{ki} = 1`$ se $`\ell_{ki} > 0`$; caso contrário, $0$ | Derivada |
| $`M_k`$ | Número de inscritos no torneio $k$, **aproximado pelo total de entradas** mostrado pela fonte (ver nota abaixo) | Listagem do SharkScope (`n_entradas_fonte`) |
| `n_entradas` | Número de entradas do jogador sorteado no torneio (auxiliar) | Lista de inscritos |
| $`N_{jh}`$ | Número de torneios do estrato $h$ no bloco $j$ | Lobby / agenda |

> O filtro do SharkScope (período e rede) deve ser **idêntico** para todos os jogadores e registrado na planilha. Por isso a janela do ROI é fixada em datas absolutas, e não relativa ao dia da consulta.
>
> **Simplificação adotada:** o número exibido pela fonte é o total de *entradas*, incluindo re-entries. No projeto, ele é usado como $`M_k`$, ou seja, número de inscritos e número de entradas são tratados como a mesma coisa. Em torneios com re-entry (Bounty Builder, Progressive KO etc.), isso superestima o número de jogadores distintos e dá mais peso a esses torneios. A limitação é discutida na [§14](#14-limitações-e-considerações-éticas).

---

## 3. Por que um estágio temporal

Na versão anterior do plano, a primeira etapa era sortear torneios dentro de cada estrato. Para isso seria preciso listar **todos** os torneios do período, o que não é viável.

A solução é sortear **blocos de tempo** antes dos torneios. Construir a lista de todos os blocos é fácil: 76 h divididas em blocos de 2 h dão $B = 38$ blocos. A lista de torneios só precisa ser montada **dentro dos blocos sorteados**. Essa é a lógica clássica da amostragem por áreas, aplicada ao tempo: em vez de listar a população inteira, listamos só as áreas sorteadas.

Ganhos adicionais:

- O efeito do horário (público diferente de madrugada e no horário nobre europeu ou brasileiro) passa a fazer parte do desenho.
- A estratificação por buy-in é aplicada **dentro de cada bloco**, o que garante que todos os estratos estejam representados.

**Variante opcional:** estratificar os blocos por *dia útil × fim de semana* e/ou *período do dia* antes do sorteio. As fórmulas da [§7](#7-estimadores) passam a valer dentro de cada estrato temporal, e os resultados são somados no final.

---

## 4. Delineamento amostral

```
População: inscrições em MTTs do PokerStars no período
│
├── 1º estágio — UPA: blocos de 2 h
│      AAS sem reposição de b blocos entre B
│
├── Estratificação dentro de cada bloco sorteado
│      Torneios do bloco classificados em H faixas de buy-in
│
├── 2º estágio — USA: torneios
│      AAS sem reposição de n_jh torneios entre N_jh, em cada (bloco, estrato)
│
└── 3º estágio — UTA: jogadores
       AAS sem reposição de m_k jogadores na lista de jogadores distintos de cada torneio
       (M_k aproximado pelo total de entradas, §2.4)
       → consulta de ROI e lucro no SharkScope
```

Todos os sorteios usam **amostragem aleatória simples sem reposição (AASs)**, com semente registrada para garantir reprodutibilidade.

---

## 5. Tamanho e alocação da amostra

Restrição: $`n_{\text{total}} = \sum_j \sum_h \sum_k m_k \le 100`$ consultas no SharkScope.

**Alocação proposta:**

| Parâmetro | Valor | Justificativa |
|---|---|---|
| $B$ | 38 | 76 h (17/10 20:00 a 21/10 00:00) em blocos de 2 h |
| $b$ | 6 | Mínimo razoável para estimar a variância entre blocos |
| $H$ | 3 | Faixas de buy-in |
| $`n_{jh}`$ | 2 | **Mínimo de 2** para estimar a variância entre torneios no estrato |
| $`m_k`$ | 2 | **Mínimo de 2** para estimar a variância dentro do torneio |
| **Total** | $6 \times 3 \times 2 \times 2 = \mathbf{72}$ jogadores | Cabe em 2 dias de coleta com a cota de 50 consultas por dia, com folga para as reservas |

> Com $`n_{jh} = 1`$ ou $`m_k = 1`$ não é possível estimar a componente de variância correspondente sem suposições extras (como colapsar estratos). Por isso o mínimo é 2 em cada estágio.

**Trade-off:** para a mesma quantidade de consultas, sortear mais torneios com menos jogadores em cada um reduz a variância quando a correlação intraclasse $\rho$ é positiva. Se a cota permitir, prefira aumentar $`n_{jh}`$ a aumentar $`m_k`$.

Também é preciso sortear jogadores de **reserva** em cada torneio (por exemplo, 3 extras) para cobrir perfis privados (ver [§11](#11-erros-não-amostrais)).

---

## 6. Protocolo de coleta

### Fase 0 — Sorteio dos blocos

1. Gerar a lista dos $B$ blocos (`AAAA-MM-DD HH:00`, em UTC ou horário de Brasília; o fuso deve ser registrado).
2. Sortear $b$ blocos com semente fixa (ver [§12](#12-implementação-de-referência-python)).

### Fase 1 — Listagem dos torneios dentro dos blocos sorteados

3. Para cada bloco sorteado, listar **todos** os MTTs com início no intervalo, usando a busca de torneios do SharkScope. Registrar ID, buy-in, horário de início e número total de entradas.

   > **Disponibilidade da listagem:** só liste um bloco depois que ele terminar. O lobby do PokerStars **não** serve como fonte, porque mostra só parte dos torneios encerrados. A janela de torneios do SharkScope parece andar com o tempo (em 19/10/2026 às 23:24, começava em 17/10 18:24, cerca de 53 h antes). Por isso, liste cada bloco o quanto antes, começando pelos mais antigos, e registre a fonte e a data de cada listagem.
4. **Descartar** freerolls e torneios com buy-in abaixo de US\$ 1,00, registrando quantos foram descartados por bloco. Depois, classificar os torneios restantes nos estratos e contar $`N_{jh}`$.
5. Sortear $`n_{jh}`$ torneios por estrato.

### Fase 2 — Sorteio dos jogadores

6. Em cada torneio sorteado, sortear uma ordem de posições de 1 a $`M_k`$ na lista de resultados do SharkScope (1 = campeão), que já tem ordem fixa antes do sorteio. As $`m_k`$ primeiras são os titulares e as seguintes, a ordem de reservas. Assim, não é preciso transcrever a lista inteira. O $`M_k`$ usado nos estimadores continua sendo o total de entradas da listagem (§2.4).
7. Anotar o nickname de cada posição, seguindo a ordem. Se a posição não existir na lista (a lista pode ter menos linhas que $`M_k`$ por causa das re-entries) ou repetir um jogador já sorteado no torneio, ela é pulada e entra a próxima da ordem. Cada jogador conta uma vez por torneio.
8. Anotar também os 10 primeiros colocados de cada torneio sorteado (`top10_torneios.csv`), para uma comparação futura com a amostra aleatória. Esse grupo **não** é uma amostra probabilística e não entra nos estimadores.

### Fase 3 — Consulta no SharkScope

9. Consultar, por dia, no máximo o número de nicknames permitido pela cota, seguindo uma ordem aleatória (não agrupar por estrato, para que a passagem do tempo não se confunda com o estrato).
10. Registrar ROI, lucro, número de torneios no período, data da consulta e o filtro usado.

### Registro

Cada sorteio, substituição e não resposta deve ficar registrado em `data/raw/log_coleta.csv`.

---

## 7. Estimadores

### 7.1 Total no torneio

$$\bar{y}_k = \frac{1}{m_k}\sum_{i=1}^{m_k} y_{ki}, \qquad \hat{T}_k = M_k\,\bar{y}_k$$

### 7.2 Total no estrato $h$ do bloco $j$

$$\hat{Y}_{jh} = \frac{N_{jh}}{n_{jh}} \sum_{k=1}^{n_{jh}} \hat{T}_k$$

### 7.3 Total no bloco $j$

$$\hat{Y}_j = \sum_{h=1}^{H} \hat{Y}_{jh}$$

### 7.4 Total populacional (estimador expansão / Horvitz–Thompson)

$$\hat{Y} = \frac{B}{b}\sum_{j=1}^{b} \hat{Y}_j$$

A probabilidade de inclusão de cada inscrição $(j,h,k,i)$ é

$$\pi_{jhki} = \frac{b}{B}\cdot\frac{n_{jh}}{N_{jh}}\cdot\frac{m_k}{M_k},$$

e $`\hat{Y} = \sum w_{jhki}\, y_{jhki}`$, com peso amostral $w = 1/\pi$.

### 7.5 Número de inscrições e média (estimador razão)

O número total de inscrições $`M_0`$ é desconhecido e também é estimado, aplicando a mesma fórmula com $`y_{ki} \equiv 1`$:

$$\hat{M}_0 = \frac{B}{b}\sum_{j}\sum_{h}\frac{N_{jh}}{n_{jh}}\sum_{k} M_k$$

O ROI médio por inscrição é o **estimador razão**:

$$\boxed{\;\hat{\bar{Y}} = \hat{R} = \frac{\hat{Y}}{\hat{M}_0} = \frac{\sum w\,y}{\sum w}\;}$$

### 7.6 Proporção de lucrativos

É o mesmo estimador, aplicado à variável indicadora $`d_{ki}`$:

$$\hat{P} = \frac{\sum w\, d}{\sum w}$$

---

## 8. Estimação da variância

### 8.1 Variância do total (estimador não viesado para três estágios)

Seguindo a decomposição por estágios de Cochran (1977, cap. 10–11) e Thompson (2012, cap. 13):

$$
\widehat{\mathrm{Var}}(\hat{Y}) =
\underbrace{B^2\left(1-\frac{b}{B}\right)\frac{s_u^2}{b}}_{\text{entre blocos}}
\;+\;
\frac{B}{b}\sum_{j=1}^{b}\widehat{\mathrm{Var}}(\hat{Y}_j)
$$

onde $`s_u^2 = \frac{1}{b-1}\sum_j \left(\hat{Y}_j - \bar{\hat{Y}}\right)^2`$ é a variância amostral dos totais estimados dos blocos e

$$
\widehat{\mathrm{Var}}(\hat{Y}_j) = \sum_{h=1}^{H}\left[
\underbrace{N_{jh}^2\left(1-\frac{n_{jh}}{N_{jh}}\right)\frac{s_{1jh}^2}{n_{jh}}}_{\text{entre torneios}}
+
\underbrace{\frac{N_{jh}}{n_{jh}}\sum_{k=1}^{n_{jh}} M_k^2\left(1-\frac{m_k}{M_k}\right)\frac{s_{2k}^2}{m_k}}_{\text{dentro do torneio}}
\right]
$$

com

- $`s_{1jh}^2`$: variância amostral dos $`\hat{T}_k`$ entre os torneios sorteados do estrato $h$ no bloco $j$;
- $`s_{2k}^2`$: variância amostral de $`y_{ki}`$ entre os jogadores sorteados no torneio $k$.

Os fatores $(1 - b/B)$, $`(1 - n_{jh}/N_{jh})`$ e $`(1 - m_k/M_k)`$ são as **correções para população finita** de cada estágio.

> **Aproximação por conglomerado último.** Quando $b/B$ é pequeno, o primeiro termo sozinho, sem o fator $(1 - b/B)$, já captura quase toda a variância e é um estimador ligeiramente conservador. Aqui $b/B = 6/38 \approx 16\%$, então a diferença entre as duas versões não é desprezível. É o que fazem `survey` (R) e `samplics` (Python) por padrão. Vale reportar as duas versões.

### 8.2 Variância da média (linearização de Taylor)

Como $`\hat{R} = \hat{Y}/\hat{M}_0`$ é uma razão, linearizamos usando a variável resíduo

$$z_{ki} = y_{ki} - \hat{R}$$

e aplicamos a fórmula da §8.1 à variável $z$:

$$\widehat{\mathrm{Var}}(\hat{R}) \approx \frac{\widehat{\mathrm{Var}}(\hat{Z})}{\hat{M}_0^{\,2}}$$

### 8.3 Intervalos de confiança

$$\hat{R} \pm t_{\,gl;\,0{,}975}\,\sqrt{\widehat{\mathrm{Var}}(\hat{R})}$$

Com poucos conglomerados primários, use graus de liberdade $gl = b - 1 = 5$ ($`t_{5;0{,}975} \approx 2{,}571`$) em vez de $z = 1{,}96$. Para $\hat{P}$, também é recomendável o intervalo de Wilson ou o logit, adaptados ao tamanho efetivo de amostra $`n_{\text{ef}} = n / \text{EPA}`$.

---

## 9. Efeito do planejamento (EPA/DEFF)

$$\text{EPA} = \frac{\widehat{\mathrm{Var}}(\hat{R})}{\widehat{\mathrm{Var}}_{\text{AAS}}(\bar{y})},
\qquad
\widehat{\mathrm{Var}}_{\text{AAS}}(\bar{y}) = \left(1-\frac{n}{\hat{M}_0}\right)\frac{s_y^2}{n}$$

- $\text{EPA} > 1$: o desenho complexo é **menos** eficiente que uma AAS com o mesmo $n$, por efeito dos conglomerados.
- $\text{EPA} < 1$: a estratificação compensa a perda causada pelos conglomerados.

Com $`m_k`$ constante, vale a aproximação de Kish, que relaciona o EPA à correlação intraclasse $\rho$:

$$\text{EPA} \approx 1 + (m - 1)\,\rho \quad\Rightarrow\quad \hat{\rho} \approx \frac{\text{EPA} - 1}{m - 1}$$

Uma hipótese a investigar é se jogadores do mesmo torneio têm desempenho correlacionado ($\rho > 0$), já que o buy-in e o horário selecionam perfis de habilidade parecidos.

---

## 10. Baseline: dataset Kaggle

O dataset do Kaggle é tratado como **população finita conhecida**, o que permite simular repetidamente os planos amostrais.

1. Aplicar o **mesmo corte de população** usado em campo: excluir freerolls e registros com buy-in abaixo de US\$ 1,00 e usar as mesmas faixas de estrato da §2.3.
2. Calcular os parâmetros verdadeiros: $`\bar{Y}_{\text{Kaggle}}`$ e $`P_{\text{Kaggle}}`$.
3. Rodar $R = 5\,000$ réplicas de:
   - **AASs** de tamanho $n = 72$;
   - **Estratificada simples** por faixa de buy-in, com alocação proporcional e de Neyman.
4. Comparar, nas simulações, vício, EQM, erro-padrão médio e cobertura empírica do IC de 95%.
5. Se o dataset tiver identificador de torneio, simular também o **desenho em conglomerados**, para obter um EPA "verdadeiro" e comparar com o EPA estimado em campo.

> As estimativas do Kaggle e do SharkScope **não** se referem à mesma população. A comparação é **metodológica** (precisão, EPA, comportamento dos estimadores), não uma comparação direta das médias.

---

## 11. Erros não amostrais

| Problema | Tratamento |
|---|---|
| **Perfil privado / opt-out** no SharkScope | Substituição pelo próximo jogador da lista de reservas do **mesmo torneio**. Registrar a taxa de substituição por estrato. Se ela for alta, considerar ajuste de não resposta por célula (torneio). |
| **Jogador "Anônimo"** na lista de resultados | Não pode ser consultado nem identificado. É tratado como perfil privado: não resposta e substituição pela próxima reserva do mesmo torneio (pulando reservas "Anônimo"). Entra na taxa de não resposta. |
| **Jogador com poucos torneios** (ROI instável) | Registrar o número de torneios do jogador no período. Fazer análise de sensibilidade excluindo quem tem menos de 30 torneios. |
| **Mesmo jogador sorteado em dois torneios** | Manter os dois registros (a unidade é a inscrição) e reaproveitar a consulta sem gastar cota. |
| **Torneio cancelado ou com poucos inscritos** ($`M_k < m_k`$) | Excluir da lista do bloco antes do sorteio e documentar o critério. |
| **Erro na listagem do bloco** (torneio omitido) | Conferir a listagem do SharkScope com a agenda oficial do PokerStars e reconciliar. |
| **Defasagem temporal** (o ROI muda entre os dias de consulta) | Usar a janela fixa de 01/10/2025 a 30/09/2026 para todos os jogadores (§2.4), em vez de "últimos 12 meses" relativo à data da consulta. |
| **Re-entry** (jogador com várias entradas no mesmo torneio) | Contar o jogador uma vez na lista deduplicada e registrar `n_entradas` (§2.1). |
| **Listagem indisponível ou incompleta** | O período foi redefinido duas vezes porque a fonte não cobria todos os blocos (lobby sem 01/10 a 10/10; lobby incompleto; SharkScope só a partir de 17/10 18:24). A regra é redefinir o período **antes** do sorteio dos torneios e refazer o sorteio dos blocos com a mesma semente (§2.1). Durante a coleta, listar cada bloco antes que ele saia da janela do SharkScope (§6). |

---

## 12. Implementação de referência (Python)

### 12.1 Sorteios reprodutíveis

```python
import numpy as np
import pandas as pd

SEMENTE = 164363
rng = np.random.default_rng(SEMENTE)

# 1º estágio: blocos de 2 h em 76 h
blocos = pd.date_range("2026-10-17 20:00", periods=38, freq="2h")  # 17/10 20:00 a 21/10 00:00
blocos_sorteados = rng.choice(blocos, size=6, replace=False)

# 2º estágio: dentro de cada (bloco, estrato)
def sortear_torneios(lista_torneios: pd.DataFrame, n: int = 2) -> pd.DataFrame:
    return lista_torneios.sample(n=min(n, len(lista_torneios)), random_state=rng.integers(1e9))

# 3º estágio: titulares + reservas
def sortear_jogadores(M_k: int, m: int = 2, reservas: int = 3) -> list[int]:
    return rng.permutation(np.arange(1, M_k + 1))[: m + reservas].tolist()
```

### 12.2 Estimadores e variância

```python
import numpy as np
import pandas as pd

def total_e_var(df: pd.DataFrame, col: str, B: int):
    """Total HT e variância não viesada para o desenho de 3 estágios.
    Colunas exigidas: bloco, estrato, torneio, N_jh, M_k, <col>."""
    tor = (df.groupby(["bloco", "estrato", "torneio"])
             .agg(m=(col, "size"), M=("M_k", "first"), N=("N_jh", "first"),
                  ybar=(col, "mean"),
                  s2=(col, lambda s: s.var(ddof=1) if len(s) > 1 else 0.0))
             .reset_index())
    tor["T"] = tor.M * tor.ybar
    tor["w"] = tor.M**2 * (1 - tor.m / tor.M) * tor.s2 / tor.m       # dentro do torneio

    sb = (tor.groupby(["bloco", "estrato"])
             .agg(n=("T", "size"), N=("N", "first"), somaT=("T", "sum"),
                  s1=("T", lambda s: s.var(ddof=1)), somaw=("w", "sum"))
             .reset_index())
    sb["Y"] = sb.N / sb.n * sb.somaT
    sb["v"] = sb.N**2 * (1 - sb.n / sb.N) * sb.s1 / sb.n + sb.N / sb.n * sb.somaw

    bl = sb.groupby("bloco").agg(Y=("Y", "sum"), v=("v", "sum"))
    b = len(bl)
    Y = B / b * bl.Y.sum()
    v = B**2 * (1 - b / B) * bl.Y.var(ddof=1) / b + B / b * bl.v.sum()
    return Y, v


def estimar_media(df: pd.DataFrame, col: str, B: int, t: float = 2.571):
    """Estimador razão (média por inscrição), EP linearizado, IC e EPA."""
    M0, _ = total_e_var(df.assign(_um=1.0), "_um", B)
    Y, _ = total_e_var(df, col, B)
    R = Y / M0
    _, vz = total_e_var(df.assign(_z=df[col] - R), "_z", B)
    var_R = vz / M0**2
    n = len(df)
    var_aas = (1 - n / M0) * df[col].var(ddof=1) / n
    ep = np.sqrt(var_R)
    return {"estimativa": R, "ep": ep, "ic95": (R - t * ep, R + t * ep),
            "M0_hat": M0, "epa": var_R / var_aas}


# Uso:
# df = pd.read_csv("data/processed/amostra_sharkscope.csv")
# df["lucrativo"] = (df["lucro"] > 0).astype(float)
# estimar_media(df, "roi", B=38)
# estimar_media(df, "lucrativo", B=38)
```

> **Validação cruzada:** confira o estimador pontual e o EP com o pacote `survey` do R. Use `svydesign(ids = ~bloco + torneio, weights = ~peso, data = df)`, com `peso = (B/b) * (N_jh/n_jh) * (M_k/m_k)`. Essa é a aproximação por conglomerado último; ela deve ficar próxima do resultado de `estimar_media`.

---

## 13. Estrutura do repositório e dicionário de dados

```
.
├── README.md
├── METODOLOGIA.md            ← este documento
├── data/
│   ├── raw/
│   │   ├── kaggle/                    # dataset original (não versionar se a licença proibir)
│   │   ├── blocos_sorteados.csv
│   │   ├── listagem_torneios.csv      # Fase 1: torneios dos blocos (a moldura é derivada daqui)
│   │   ├── jogadores_sorteados.csv
│   │   └── log_coleta.csv
│   └── processed/
│       └── amostra_sharkscope.csv
├── src/
│   ├── sorteio.py
│   ├── estimadores.py
│   └── simulacao_kaggle.py
├── notebooks/
│   └── analise.ipynb
└── relatorio/
```

**`amostra_sharkscope.csv`**

| Coluna | Tipo | Descrição |
|---|---|---|
| `bloco` | str | Início do bloco (ISO 8601) |
| `estrato` | int | 1 = Micro, 2 = Low, 3 = Mid/High |
| `torneio` | str | ID do torneio no PokerStars |
| `buyin` | float | Buy-in em US\$ |
| `N_jh` | int | Nº de torneios do estrato no bloco |
| `M_k` | int | Nº de jogadores distintos inscritos no torneio |
| `n_entradas` | int | Nº de entradas do jogador no torneio (re-entries) |
| `jogador_id` | str | Hash do nickname (ver §14) |
| `posicao_lista` | int | Posição sorteada na lista de inscritos |
| `substituto` | bool | Se é reserva de um titular com perfil privado |
| `roi` | float | Total ROI (%) no filtro definido |
| `lucro` | float | Profit (US\$) no filtro definido |
| `n_torneios_jogador` | int | Nº de torneios do jogador no filtro |
| `data_consulta` | date | Data da consulta no SharkScope |
| `filtro` | str | Descrição do filtro (rede, período) |

---

## 14. Limitações e considerações éticas

- **Unidade de inscrição × jogador.** Jogadores frequentes têm maior probabilidade de inclusão. Para estimar o ROI *por jogador distinto*, seria preciso ponderar cada inscrição por $`1/f_i`$, onde $`f_i`$ é o número de inscrições do jogador no período. Esse dado pode ser aproximado pelo próprio SharkScope e fica como extensão do trabalho.
- **$`M_k`$ aproximado pelas entradas.** O tamanho de cada torneio é o total de entradas, com re-entries (§2.4). Em torneios com re-entry, $`M_k`$ fica maior que o número de jogadores distintos, e o peso $`M_k/m_k`$ desses torneios fica inflado. O sorteio dos jogadores continua sendo feito na lista sem repetições.
- **Poucos conglomerados primários** ($b = 6$): os graus de liberdade são baixos e o IC fica largo. Isso é esperado, e discutir esse ponto faz parte da análise.
- **ROI histórico tem alta variância** e cauda pesada. Considere reportar também a mediana e fazer análise de sensibilidade com ROI winsorizado.
- **Validade externa:** os resultados valem para MTTs do PokerStars.com no período escolhido, e não para o poker online em geral. O período tem só 76 h (sábado à noite, domingo, segunda e terça), limitado pela janela do SharkScope e pelo prazo. Não cobre uma semana inteira nem eventos que acontecem só em outros dias.
- **Termos de uso:** toda a coleta no SharkScope é **manual e respeita a cota da conta**. Não se usa scraping automatizado nem do SharkScope nem do PokerStars.
- **Privacidade:** nicknames são dados públicos, mas no repositório devem ser **pseudonimizados** (hash com sal mantido fora do Git). Os nicknames originais não devem ser publicados.

---

## 15. Referências

- BOLFARINE, H.; BUSSAB, W. O. *Elementos de Amostragem*. São Paulo: Blucher, 2005.
- COCHRAN, W. G. *Sampling Techniques*. 3. ed. New York: Wiley, 1977.
- KISH, L. *Survey Sampling*. New York: Wiley, 1965.
- LOHR, S. L. *Sampling: Design and Analysis*. 3. ed. Boca Raton: CRC Press, 2022.
- SÄRNDAL, C.-E.; SWENSSON, B.; WRETMAN, J. *Model Assisted Survey Sampling*. New York: Springer, 1992.
- THOMPSON, S. K. *Sampling*. 3. ed. Hoboken: Wiley, 2012.
